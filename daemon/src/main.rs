// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Demone dati di Vela (D-039). Raccoglie lo stato di sistema in moduli e lo scrive su stdout come righe JSON
//! (protocollo in `proto.rs`). Sola lettura: non esegue comandi, non scrive file, non apre socket né rete.
//! Vela lo avvia come processo figlio e tiene aperto stdin: quando Vela finisce, stdin si chiude e il demone esce.
//!
//! ```text
//! vela-daemon [--modules night,sway]    servizio (default: nessun modulo)
//! vela-daemon --once [--modules …]      stampa lo stato iniziale di ogni modulo e termina (diagnostica)
//! ```
#![forbid(unsafe_code)]

mod hub;
mod json;
mod modules;
mod proto;

use hub::Hub;
use modules::{Event, Module};
use std::io::{self, Write};
use std::process;
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const TICK_EVERY: Duration = Duration::from_secs(5);
const MIN_GAP: Duration = Duration::from_millis(100);
const ONCE_WAIT: Duration = Duration::from_secs(2);

fn unix_now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_secs())
}

/// Avvia un thread per modulo. Un panico in un modulo diventa un messaggio di errore e non tocca gli altri.
fn spawn_modules(mods: Vec<Box<dyn Module>>, tx: &Sender<Event>) {
    for m in mods {
        let name = m.name().to_string();
        let tx = tx.clone();
        let _ = thread::Builder::new().name(name.clone()).spawn(move || {
            let tx2 = tx.clone();
            let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(move || m.run(tx2)));
            if r.is_err() {
                let _ = tx.send(Event::Error(name, "il modulo si è fermato inaspettatamente".into()));
            }
        });
    }
}

fn emit<W: Write>(out: &mut W, lines: Vec<String>) -> io::Result<()> {
    for l in lines {
        writeln!(out, "{l}")?;
    }
    out.flush()
}

/// Ciclo principale: scrive `hello`, poi gli stati cambiati e un `tick` ogni `tick_every`, finché arriva `Quit`
/// o il canale si chiude. Restituisce `Err` se la scrittura fallisce (Vela non c'è più).
fn serve<W: Write>(out: &mut W, rx: &Receiver<Event>, active: &[String], tick_every: Duration) -> io::Result<()> {
    let mut hub = Hub::new(MIN_GAP);
    emit(out, vec![proto::hello(active)])?;
    let mut next_tick = Instant::now() + tick_every;
    loop {
        let now = Instant::now();
        let deadline = hub.next_deadline().map_or(next_tick, |d| d.min(next_tick));
        let mut lines = Vec::new();
        match rx.recv_timeout(deadline.saturating_duration_since(now)) {
            Ok(Event::Quit) | Err(RecvTimeoutError::Disconnected) => return Ok(()),
            Ok(Event::State(m, data)) => {
                if active.contains(&m) {
                    lines.extend(hub.submit(&m, data, Instant::now()));
                }
            }
            Ok(Event::Error(m, msg)) => lines.push(proto::error(&m, &msg)),
            Err(RecvTimeoutError::Timeout) => {}
        }
        let now = Instant::now();
        lines.extend(hub.due(now));
        if now >= next_tick {
            lines.push(proto::tick(unix_now()));
            next_tick = now + tick_every;
        }
        emit(out, lines)?;
    }
}

/// Diagnostica: stato iniziale di ogni modulo, poi esce.
fn once<W: Write>(out: &mut W, rx: &Receiver<Event>, active: &[String], wait: Duration) -> io::Result<()> {
    writeln!(out, "{}", proto::hello(active))?;
    let mut missing: Vec<&String> = active.iter().collect();
    let end = Instant::now() + wait;
    while !missing.is_empty() {
        match rx.recv_timeout(end.saturating_duration_since(Instant::now())) {
            Ok(Event::State(m, data)) => {
                if let Some(i) = missing.iter().position(|x| **x == m) {
                    missing.remove(i);
                    writeln!(out, "{}", proto::state(&m, &data))?;
                }
            }
            Ok(Event::Error(m, msg)) => writeln!(out, "{}", proto::error(&m, &msg))?,
            Ok(Event::Quit) | Err(_) => break,
        }
    }
    for m in missing {
        writeln!(out, "{}", proto::error(m, "nessuno stato ricevuto"))?;
    }
    out.flush()
}

struct Args {
    once: bool,
    modules: Vec<String>,
}

fn parse_args() -> Result<Args, String> {
    let mut a = Args { once: false, modules: Vec::new() };
    let mut it = std::env::args().skip(1);
    while let Some(x) = it.next() {
        match x.as_str() {
            "--once" => a.once = true,
            "--modules" => {
                let v = it.next().ok_or("--modules richiede un elenco")?;
                a.modules = v.split(',').filter(|s| !s.is_empty()).map(str::to_string).collect();
            }
            "--version" => {
                println!("vela-daemon {} (protocollo {})", env!("CARGO_PKG_VERSION"), proto::VERSION);
                process::exit(0);
            }
            _ => return Err(format!("argomento non riconosciuto: {}", proto::clip(&x))),
        }
    }
    Ok(a)
}

fn main() {
    let args = parse_args().unwrap_or_else(|e| {
        eprintln!("vela-daemon: {e}\nuso: vela-daemon [--once] [--modules a,b]");
        process::exit(2);
    });
    let mut wanted: Vec<String> = Vec::new();
    for n in args.modules {
        if proto::valid_module_name(&n) && !wanted.contains(&n) {
            wanted.push(n);
        } else {
            eprintln!("vela-daemon: nome di modulo non valido o ripetuto: {}", proto::clip(&n));
        }
    }
    let (mods, unknown) = modules::build(&wanted);
    for u in &unknown {
        eprintln!("vela-daemon: modulo sconosciuto: {u}");
    }
    let active: Vec<String> = mods.iter().map(|m| m.name().to_string()).collect();

    let (tx, rx) = mpsc::channel::<Event>();
    spawn_modules(mods, &tx);
    let stdout = io::stdout();
    let mut out = stdout.lock();

    if args.once {
        let _ = once(&mut out, &rx, &active, ONCE_WAIT);
        return;
    }
    // Vela tiene aperto stdin: alla chiusura (o alla sua morte) si esce. Il contenuto non serve e non viene tenuto.
    let quit = tx.clone();
    let _ = thread::Builder::new().name("stdin".into()).spawn(move || {
        let _ = io::copy(&mut io::stdin().lock(), &mut io::sink());
        let _ = quit.send(Event::Quit);
    });
    // Per i moduli richiesti ma sconosciuti si manda subito l'errore, così il QML sa perché mancano dati.
    for u in unknown {
        let _ = tx.send(Event::Error(proto::clip(&u), "modulo sconosciuto".into()));
    }
    drop(tx);
    let _ = serve(&mut out, &rx, &active, TICK_EVERY);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::json::{parse, Value};

    /// Modulo di prova: manda gli stati dati (o va in panico).
    struct Fake {
        name: &'static str,
        states: Vec<Value>,
        panic: bool,
    }
    impl Module for Fake {
        fn name(&self) -> &'static str {
            self.name
        }
        fn run(self: Box<Self>, tx: Sender<Event>) {
            if self.panic {
                panic!("prova");
            }
            for s in self.states {
                let _ = tx.send(Event::State(self.name.to_string(), s));
            }
        }
    }

    fn lines(buf: &[u8]) -> Vec<Value> {
        String::from_utf8(buf.to_vec()).unwrap().lines().map(|l| parse(l).unwrap()).collect()
    }
    fn n(x: f64) -> Value {
        Value::Num(x)
    }
    fn ty(v: &Value) -> &str {
        v.get("type").unwrap().as_str().unwrap()
    }
    fn quit_after(tx: &Sender<Event>, ms: u64) {
        let q = tx.clone();
        thread::spawn(move || {
            thread::sleep(Duration::from_millis(ms));
            let _ = q.send(Event::Quit);
        });
    }

    #[test]
    fn serve_scrive_hello_stati_e_tick_poi_esce_su_quit() {
        let (tx, rx) = mpsc::channel();
        spawn_modules(vec![Box::new(Fake { name: "a", states: vec![n(1.0)], panic: false })], &tx);
        quit_after(&tx, 150);
        let mut out = Vec::new();
        serve(&mut out, &rx, &["a".to_string()], Duration::from_millis(30)).unwrap();
        let v = lines(&out);
        assert_eq!(ty(&v[0]), "hello");
        assert_eq!(v[0].get("v").unwrap().as_i64(), Some(1));
        let states: Vec<_> = v.iter().filter(|x| ty(x) == "state").collect();
        assert_eq!(states.len(), 1);
        assert_eq!(states[0].get("data").unwrap().as_i64(), Some(1));
        assert!(v.iter().filter(|x| ty(x) == "tick").count() >= 2);
    }

    #[test]
    fn serve_ignora_stati_di_moduli_non_attivi_e_riporta_gli_errori() {
        let (tx, rx) = mpsc::channel();
        tx.send(Event::State("altro".into(), n(1.0))).unwrap();
        tx.send(Event::Error("a".into(), "guasto".into())).unwrap();
        tx.send(Event::Quit).unwrap();
        let mut out = Vec::new();
        serve(&mut out, &rx, &["a".to_string()], Duration::from_secs(60)).unwrap();
        let v = lines(&out);
        assert_eq!(v.len(), 2);
        assert_eq!(ty(&v[1]), "error");
        assert_eq!(v[1].get("message").unwrap().as_str(), Some("guasto"));
    }

    #[test]
    fn un_modulo_che_va_in_panico_non_ferma_gli_altri() {
        let (tx, rx) = mpsc::channel();
        spawn_modules(
            vec![
                Box::new(Fake { name: "a", states: vec![], panic: true }),
                Box::new(Fake { name: "b", states: vec![n(7.0)], panic: false }),
            ],
            &tx,
        );
        quit_after(&tx, 200);
        let mut out = Vec::new();
        serve(&mut out, &rx, &["a".to_string(), "b".to_string()], Duration::from_secs(60)).unwrap();
        let v = lines(&out);
        let of = |m: &str, t: &str| v.iter().any(|x| ty(x) == t && x.get("module").and_then(Value::as_str) == Some(m));
        assert!(of("a", "error"));
        assert!(of("b", "state"));
    }

    #[test]
    fn serve_esce_con_errore_se_la_scrittura_fallisce() {
        struct Broken;
        impl Write for Broken {
            fn write(&mut self, _: &[u8]) -> io::Result<usize> {
                Err(io::ErrorKind::BrokenPipe.into())
            }
            fn flush(&mut self) -> io::Result<()> {
                Ok(())
            }
        }
        let (_tx, rx) = mpsc::channel::<Event>();
        assert!(serve(&mut Broken, &rx, &[], Duration::from_secs(60)).is_err());
    }

    #[test]
    fn once_stampa_gli_stati_iniziali_e_segnala_chi_manca() {
        let (tx, rx) = mpsc::channel();
        let active = vec!["a".to_string(), "b".to_string()];
        spawn_modules(vec![Box::new(Fake { name: "a", states: vec![n(1.0)], panic: false })], &tx);
        let mut out = Vec::new();
        once(&mut out, &rx, &active, Duration::from_millis(200)).unwrap();
        let v = lines(&out);
        assert_eq!(v.len(), 3);
        assert_eq!(v[1].get("module").unwrap().as_str(), Some("a"));
        assert_eq!(ty(&v[2]), "error");
        assert_eq!(v[2].get("module").unwrap().as_str(), Some("b"));
    }

    #[test]
    fn i_nomi_sconosciuti_non_sono_fatali() {
        let (mods, unknown) = modules::build(&["boh".to_string()]);
        assert!(mods.is_empty());
        assert_eq!(unknown, vec!["boh".to_string()]);
    }
}
