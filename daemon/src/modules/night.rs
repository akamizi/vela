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
const EVERY: Duration = Duration::from_secs(2);

pub struct Night {
    proc_root: PathBuf,
    every: Duration,
}

impl Night {
    pub fn new() -> Self {
        Night { proc_root: PathBuf::from("/proc"), every: EVERY }
    }
}

/// Vero se esiste un processo di nome esatto `gammastep` che appartiene a `uid`.
/// Come `pgrep -x`, ma solo dell'utente: il gammastep di un altro utente non riguarda questa sessione.
fn scan(proc_root: &Path, uid: u32) -> bool {
    let Ok(dir) = fs::read_dir(proc_root) else { return false };
    dir.flatten().any(|e| {
        let name = e.file_name();
        let name = name.to_string_lossy();
        if name.is_empty() || !name.bytes().all(|b| b.is_ascii_digit()) {
            return false;
        }
        let p = e.path();
        let comm = fs::read_to_string(p.join("comm")).unwrap_or_default();
        comm.trim_end_matches('\n') == PROCESS && fs::metadata(&p).map_or(false, |m| m.uid() == uid)
    })
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
        let mut last: Option<bool> = None;
        loop {
            let on = scan(&self.proc_root, me);
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
        assert!(!scan(&f.0, me()));
        f.proc("103", "gammastep");
        assert!(scan(&f.0, me()));
    }

    #[test]
    fn ignora_le_voci_che_non_sono_processi_e_i_processi_altrui() {
        let f = Fake::new();
        f.proc("abc", "gammastep");
        f.proc("1x", "gammastep");
        assert!(!scan(&f.0, me()));
        f.proc("7", "gammastep");
        assert!(scan(&f.0, me()));
        assert!(!scan(&f.0, me().wrapping_add(1)), "un altro utente non conta");
    }

    #[test]
    fn proc_mancante_vuol_dire_spento() {
        assert!(!scan(Path::new("/non/esiste/vela"), 0));
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
