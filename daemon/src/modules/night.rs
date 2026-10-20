// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Modulo `night`: la luce notturna è accesa se un processo `gammastep` dell'utente è in esecuzione.
//! Sostituisce `pgrep -x gammastep` del QML: si leggono i nomi dei processi da /proc, senza lanciare niente.
//! Stato: `{"on": true|false}`, mandato all'inizio e a ogni cambiamento.

use super::{Event, Module};
use crate::json::Value;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::sync::mpsc::Sender;
use std::thread::sleep;
use std::time::Duration;

const PROCESS: &str = "gammastep";
const EVERY: Duration = Duration::from_secs(5);

pub struct Night {
    proc_root: PathBuf,
    every: Duration,
}

impl Night {
    pub fn new() -> Self {
        Night { proc_root: PathBuf::from("/proc"), every: EVERY }
    }
}

/// Il processo `pid` è un `gammastep` dell'utente `uid`?
fn is_gammastep(proc_root: &Path, pid: u64, uid: u32) -> bool {
    let p = proc_root.join(pid.to_string());
    fs::read_to_string(p.join("comm")).map_or(false, |c| c.trim_end_matches('\n') == PROCESS) && fs::metadata(&p).map_or(false, |m| m.uid() == uid)
}

/// Pid del primo processo di nome esatto `gammastep` che appartiene a `uid`.
/// Come `pgrep -x`, ma solo dell'utente: il gammastep di un altro utente non riguarda questa sessione.
fn scan(proc_root: &Path, uid: u32) -> Option<u64> {
    let dir = fs::read_dir(proc_root).ok()?;
    dir.flatten().find_map(|e| {
        let name = e.file_name();
        let pid: u64 = name.to_str().filter(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))?.parse().ok()?;
        is_gammastep(proc_root, pid, uid).then_some(pid)
    })
}

/// Ultimo pid assegnato dal kernel (quinto campo di /proc/loadavg): se non cambia, non è nato nessun processo.
fn last_pid(proc_root: &Path) -> Option<u64> {
    fs::read_to_string(proc_root.join("loadavg")).ok()?.split_whitespace().nth(4)?.parse().ok()
}

/// Rilevamento a basso costo: una scansione completa di /proc costa ~14 ms con qualche centinaio di processi,
/// quindi si rifà solo quando è nato un processo nuovo; finché gammastep vive basta controllare il suo pid.
struct Detector {
    proc_root: PathBuf,
    uid: u32,
    found: Option<u64>,
    seen_last_pid: Option<u64>,
}

impl Detector {
    fn new(proc_root: PathBuf, uid: u32) -> Self {
        Detector { proc_root, uid, found: None, seen_last_pid: None }
    }

    fn check(&mut self) -> bool {
        if let Some(pid) = self.found {
            if is_gammastep(&self.proc_root, pid, self.uid) {
                return true;
            }
            self.found = None; // finito (o pid riciclato): si cerca di nuovo
        }
        // Il contatore si legge prima della scansione: un processo nato nel frattempo lo si vede al giro dopo.
        let lp = last_pid(&self.proc_root);
        if lp.is_some() && lp == self.seen_last_pid {
            return false;
        }
        self.seen_last_pid = lp;
        self.found = scan(&self.proc_root, self.uid);
        self.found.is_some()
    }
}

fn state(on: bool) -> Value {
    Value::Obj(vec![("on".to_string(), Value::Bool(on))])
}

impl Module for Night {
    fn name(&self) -> &'static str {
        "night"
    }

    fn run(self: Box<Self>, tx: Sender<Event>) {
        // L'utente del demone è il proprietario della sua cartella in /proc.
        let Ok(me) = fs::metadata("/proc/self").map(|m| m.uid()) else {
            let _ = tx.send(Event::Error("night".into(), "utente non determinabile".into()));
            return;
        };
        let mut det = Detector::new(self.proc_root.clone(), me);
        let mut last: Option<bool> = None;
        loop {
            let on = det.check();
            if last != Some(on) {
                last = Some(on);
                if tx.send(Event::State("night".into(), state(on))).is_err() {
                    return; // il ciclo principale è finito
                }
            }
            sleep(self.every);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::mpsc;

    static N: AtomicUsize = AtomicUsize::new(0);

    /// Finto /proc in una cartella temporanea.
    struct Fake(PathBuf);
    impl Fake {
        fn new() -> Self {
            let d = std::env::temp_dir().join(format!("vela-night-{}-{}", std::process::id(), N.fetch_add(1, Ordering::SeqCst)));
            fs::create_dir_all(&d).unwrap();
            Fake(d)
        }
        fn loadavg(&self, last: u64) {
            fs::write(self.0.join("loadavg"), format!("0.10 0.20 0.30 1/200 {last}\n")).unwrap();
        }
        fn proc(&self, pid: &str, comm: &str) {
            fs::create_dir_all(self.0.join(pid)).unwrap();
            fs::write(self.0.join(pid).join("comm"), format!("{comm}\n")).unwrap();
        }
    }
    impl Drop for Fake {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn me() -> u32 {
        fs::metadata("/proc/self").unwrap().uid()
    }

    #[test]
    fn trova_solo_il_nome_esatto() {
        let f = Fake::new();
        f.proc("100", "sway");
        f.proc("101", "gammastep-indicator");
        f.proc("102", "my-gammastep");
        assert_eq!(scan(&f.0, me()), None);
        f.proc("103", "gammastep");
        assert_eq!(scan(&f.0, me()), Some(103));
    }

    #[test]
    fn ignora_le_voci_che_non_sono_processi_e_i_processi_altrui() {
        let f = Fake::new();
        f.proc("abc", "gammastep");
        f.proc("1x", "gammastep");
        assert_eq!(scan(&f.0, me()), None);
        f.proc("7", "gammastep");
        assert_eq!(scan(&f.0, me()), Some(7));
        assert_eq!(scan(&f.0, me().wrapping_add(1)), None, "un altro utente non conta");
    }

    #[test]
    fn proc_mancante_vuol_dire_spento() {
        assert_eq!(scan(Path::new("/non/esiste/vela"), 0), None);
    }

    #[test]
    fn senza_nuovi_processi_non_si_riscansiona() {
        let f = Fake::new();
        f.loadavg(100);
        let mut d = Detector::new(f.0.clone(), me());
        assert!(!d.check());
        f.proc("9", "gammastep"); // nato "senza" che il contatore cambi: non si deve vedere (prova che non scansiona)
        assert!(!d.check());
        f.loadavg(101); // adesso è nato un processo: si scansiona e si trova
        assert!(d.check());
        // finché vive, basta il suo pid: anche se il contatore non cambia, la fine si vede
        fs::remove_dir_all(f.0.join("9")).unwrap();
        assert!(!d.check());
    }

    #[test]
    fn senza_loadavg_si_scansiona_sempre() {
        let f = Fake::new();
        let mut d = Detector::new(f.0.clone(), me());
        assert!(!d.check());
        f.proc("9", "gammastep");
        assert!(d.check());
    }

    #[test]
    fn pid_riciclato_da_un_altro_programma_non_conta() {
        let f = Fake::new();
        f.loadavg(1);
        f.proc("9", "gammastep");
        let mut d = Detector::new(f.0.clone(), me());
        assert!(d.check());
        f.proc("9", "firefox"); // stesso pid, altro programma
        assert!(!d.check());
    }

    #[test]
    fn manda_lo_stato_all_inizio_e_solo_ai_cambi() {
        let f = Fake::new();
        let m = Box::new(Night { proc_root: f.0.clone(), every: Duration::from_millis(20) });
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || m.run(tx));
        let get = || match rx.recv_timeout(Duration::from_secs(2)).unwrap() {
            Event::State(n, v) => {
                assert_eq!(n, "night");
                v.get("on").unwrap().to_json()
            }
            _ => panic!("evento inatteso"),
        };
        assert_eq!(get(), "false");
        assert!(rx.recv_timeout(Duration::from_millis(100)).is_err(), "nessun messaggio senza cambi");
        f.proc("9", "gammastep");
        assert_eq!(get(), "true");
        fs::remove_dir_all(f.0.join("9")).unwrap();
        assert_eq!(get(), "false");
    }
}
