// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Modulo `sway`: elenco degli input (tastiere e touchpad) con layout attivo e stato `send_events`, più il layout
//! del contenitore che ha il focus, dal socket IPC di Sway.
//! Sostituisce `swaymsg -t get_inputs` periodico e l'abbonamento `swaymsg -m` del QML.
//!
//! Protocollo i3/Sway: `"i3-ipc"` + lunghezza (u32) + tipo (u32) + contenuto, interi in ordine nativo.
//! Ci si abbona agli eventi su una connessione dedicata; a ogni evento utile si rilegge `get_inputs` (input) o
//! `get_tree` (layout) su una connessione breve (con scadenza), così un Sway che non risponde non blocca il resto.
//! Il cambio di layout (`layout tabbed`, ecc.) non genera un evento di Sway: si rilegge al cambio di focus, finestre
//! e workspace e quando scatta una scorciatoia (evento `binding`) il cui comando contiene `layout`.
//!
//! Stato: `{"inputs":[{"id","name","type","send_events","layouts":[…],"layout_index"}],"layout":"splith|splitv|stacking|tabbed|floating|"}`
//! (`layout` vuoto se non si sa).
//! Il contenuto che arriva da Sway (nomi) è limitato in lunghezza e in numero prima di uscire.

use super::{Event, Module};
use crate::json::{self, Value};
use crate::proto::clip;
use std::io::{self, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::sync::mpsc::Sender;
use std::thread::sleep;
use std::time::Duration;

const MAGIC: &[u8; 6] = b"i3-ipc";
const SUBSCRIBE: u32 = 2;
const GET_TREE: u32 = 4;
const GET_INPUTS: u32 = 100;
const EVENT_WORKSPACE: u32 = 0x8000_0000;
const EVENT_WINDOW: u32 = 0x8000_0003;
const EVENT_BINDING: u32 = 0x8000_0005;
const EVENT_INPUT: u32 = 0x8000_0015;
/// Profondità massima della ricerca nell'albero delle finestre.
const MAX_TREE_DEPTH: usize = 40;
/// Risposte più grandi di così non sono credibili (un elenco di input è di pochi KiB, un albero di finestre qualche decina).
const MAX_PAYLOAD: u32 = 1 << 20;
const MAX_INPUTS: usize = 64;
const MAX_LAYOUTS: usize = 16;
const QUERY_TIMEOUT: Duration = Duration::from_secs(2);
const RETRY: Duration = Duration::from_secs(3);
/// Pausa tra un evento e la lettura: gli eventi di un cambio di configurazione arrivano a raffica.
const SETTLE: Duration = Duration::from_millis(30);

pub struct Sway {
    socket: Option<PathBuf>,
    retry: Duration,
    settle: Duration,
}

impl Sway {
    pub fn new() -> Self {
        let socket = std::env::var_os("SWAYSOCK").or_else(|| std::env::var_os("I3SOCK")).filter(|v| !v.is_empty()).map(PathBuf::from);
        Sway { socket, retry: RETRY, settle: SETTLE }
    }
}

// --- fotogrammi ----------------------------------------------------------------------------

fn encode_frame(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut v = Vec::with_capacity(14 + payload.len());
    v.extend_from_slice(MAGIC);
    v.extend_from_slice(&(payload.len() as u32).to_ne_bytes());
    v.extend_from_slice(&kind.to_ne_bytes());
    v.extend_from_slice(payload);
    v
}

fn read_frame<R: Read>(r: &mut R) -> io::Result<(u32, Vec<u8>)> {
    let mut head = [0u8; 14];
    r.read_exact(&mut head)?;
    if &head[..6] != MAGIC {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "intestazione IPC non valida"));
    }
    let len = u32::from_ne_bytes([head[6], head[7], head[8], head[9]]);
    let kind = u32::from_ne_bytes([head[10], head[11], head[12], head[13]]);
    if len > MAX_PAYLOAD {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "messaggio IPC troppo grande"));
    }
    let mut body = vec![0u8; len as usize];
    r.read_exact(&mut body)?;
    Ok((kind, body))
}

// --- dati ----------------------------------------------------------------------------------

fn text(v: Option<&Value>) -> String {
    v.and_then(Value::as_str).map(clip).unwrap_or_default()
}

/// Dal risultato di `get_inputs` allo stato mandato a Vela: solo i campi che servono, con limiti.
fn inputs_list(reply: &Value) -> Result<Value, String> {
    let list = reply.as_array().ok_or("risposta di get_inputs non valida")?;
    let inputs: Vec<Value> = list
        .iter()
        .take(MAX_INPUTS)
        .map(|i| {
            let layouts: Vec<Value> = i
                .get("xkb_layout_names")
                .and_then(Value::as_array)
                .unwrap_or(&[])
                .iter()
                .take(MAX_LAYOUTS)
                .filter_map(|l| l.as_str().map(|s| Value::Str(clip(s))))
                .collect();
            let index = i.get("xkb_active_layout_index").and_then(Value::as_i64).filter(|n| (0..MAX_LAYOUTS as i64).contains(n)).unwrap_or(0);
            Value::Obj(vec![
                ("id".into(), Value::Str(text(i.get("identifier")))),
                ("name".into(), Value::Str(text(i.get("name")))),
                ("type".into(), Value::Str(text(i.get("type")))),
                ("send_events".into(), Value::Str(text(i.get("libinput").and_then(|l| l.get("send_events"))))),
                ("layouts".into(), Value::Arr(layouts)),
                ("layout_index".into(), Value::Num(index as f64)),
            ])
        })
        .collect();
    Ok(Value::Arr(inputs))
}

/// Nome del layout come lo usa Vela, dal nome di Sway (`stacked` diventa `stacking`); altri valori: vuoto.
fn layout_name(sway: Option<&str>) -> &'static str {
    match sway {
        Some("splith") => "splith",
        Some("splitv") => "splitv",
        Some("stacked") => "stacking",
        Some("tabbed") => "tabbed",
        _ => "",
    }
}

/// Layout del contenitore che ha il focus: quello del genitore della finestra (è ciò che cambia `layout …`),
/// `floating` se la finestra è flottante, quello del workspace se è vuoto.
fn focus_layout(tree: &Value) -> &'static str {
    fn walk(n: &Value, parent: Option<&Value>, floating: bool, depth: usize) -> Option<&'static str> {
        if depth > MAX_TREE_DEPTH {
            return None;
        }
        if n.get("focused").and_then(Value::as_bool) == Some(true) {
            let has_children = n.get("nodes").and_then(Value::as_array).is_some_and(|c| !c.is_empty());
            let is_floating = floating || n.get("type").and_then(Value::as_str) == Some("floating_con");
            return Some(if is_floating {
                "floating"
            } else if has_children || n.get("type").and_then(Value::as_str) == Some("workspace") {
                layout_name(n.get("layout").and_then(Value::as_str))
            } else {
                layout_name(parent.and_then(|p| p.get("layout")).and_then(Value::as_str))
            });
        }
        for (key, fl) in [("nodes", floating), ("floating_nodes", true)] {
            for c in n.get(key).and_then(Value::as_array).unwrap_or(&[]) {
                if let Some(l) = walk(c, Some(n), fl, depth + 1) {
                    return Some(l);
                }
            }
        }
        None
    }
    walk(tree, None, false, 0).unwrap_or("")
}

/// Un evento di finestra, workspace o scorciatoia cambia il layout mostrato? (i cambi di titolo, frequentissimi, no)
fn layout_event(kind: u32, body: &[u8]) -> bool {
    let Some(v) = std::str::from_utf8(body).ok().and_then(|t| json::parse(t).ok()) else { return false };
    let change = v.get("change").and_then(Value::as_str).unwrap_or("");
    match kind {
        EVENT_WINDOW => matches!(change, "focus" | "new" | "close" | "move" | "floating"),
        EVENT_WORKSPACE => matches!(change, "focus" | "init" | "empty" | "move"),
        EVENT_BINDING => v.get("binding").and_then(|b| b.get("command")).and_then(Value::as_str).is_some_and(|c| c.contains("layout")),
        _ => false,
    }
}

fn state(inputs: &Value, layout: &str) -> Value {
    Value::Obj(vec![("inputs".into(), inputs.clone()), ("layout".into(), Value::Str(layout.into()))])
}

fn empty_state() -> Value {
    state(&Value::Arr(vec![]), "")
}

// --- connessioni ---------------------------------------------------------------------------

fn connect(path: &Path) -> io::Result<UnixStream> {
    let s = UnixStream::connect(path)?;
    s.set_write_timeout(Some(QUERY_TIMEOUT))?;
    Ok(s)
}

/// Una domanda su una connessione nuova, con scadenza in lettura.
fn query(path: &Path, kind: u32) -> Result<Value, String> {
    let mut s = connect(path).map_err(|e| format!("connessione a Sway: {e}"))?;
    s.set_read_timeout(Some(QUERY_TIMEOUT)).map_err(|e| e.to_string())?;
    s.write_all(&encode_frame(kind, b"")).map_err(|e| format!("scrittura a Sway: {e}"))?;
    let (k, body) = read_frame(&mut s).map_err(|e| format!("lettura da Sway: {e}"))?;
    if k != kind {
        return Err("risposta di tipo inatteso".into());
    }
    let text = String::from_utf8(body).map_err(|_| "risposta non UTF-8".to_string())?;
    json::parse(&text).map_err(|e| format!("risposta non valida: {}", e.0))
}

/// Esito di una sessione: o Sway è sparito (si riprova) o il ciclo principale è finito (si esce).
enum End {
    Lost(String),
    Quit,
}

impl Sway {
    fn session(&self, path: &Path, tx: &Sender<Event>, delivered: &mut bool) -> End {
        // Prima l'abbonamento, poi la lettura: così nessun cambiamento si perde in mezzo.
        let mut sub = match connect(path) {
            Ok(s) => s,
            Err(e) => return End::Lost(format!("connessione a Sway: {e}")),
        };
        if let Err(e) = sub.write_all(&encode_frame(SUBSCRIBE, b"[\"input\",\"window\",\"workspace\",\"binding\"]")) {
            return End::Lost(format!("abbonamento a Sway: {e}"));
        }
        match read_frame(&mut sub) {
            Ok((SUBSCRIBE, body)) => {
                let ok = String::from_utf8(body).ok().and_then(|t| json::parse(&t).ok()).and_then(|v| v.get("success").and_then(Value::as_bool));
                if ok != Some(true) {
                    return End::Lost("Sway ha rifiutato l'abbonamento agli eventi input".into());
                }
            }
            Ok(_) => return End::Lost("risposta all'abbonamento inattesa".into()),
            Err(e) => return End::Lost(format!("abbonamento a Sway: {e}")),
        }
        let read_inputs = || query(path, GET_INPUTS).and_then(|v| inputs_list(&v));
        // Il layout è un di più: se non si legge, resta vuoto e gli input funzionano comunque.
        let read_layout = || query(path, GET_TREE).map(|t| focus_layout(&t)).unwrap_or("");
        let mut inputs = match read_inputs() {
            Ok(i) => i,
            Err(e) => return End::Lost(e),
        };
        let mut layout = read_layout();
        loop {
            if tx.send(Event::State("sway".into(), state(&inputs, layout))).is_err() {
                return End::Quit;
            }
            *delivered = true;
            // Si aspetta il prossimo evento utile; gli altri (titoli, ecc.) si ignorano.
            loop {
                match read_frame(&mut sub) {
                    Ok((EVENT_INPUT, _)) => {
                        sleep(self.settle);
                        match read_inputs() {
                            Ok(i) => inputs = i,
                            Err(e) => return End::Lost(e),
                        }
                        break;
                    }
                    Ok((kind, body)) if layout_event(kind, &body) => {
                        sleep(self.settle);
                        layout = read_layout();
                        break;
                    }
                    Ok(_) => {}
                    Err(e) => return End::Lost(format!("connessione a Sway chiusa: {e}")),
                }
            }
        }
    }
}

impl Module for Sway {
    fn name(&self) -> &'static str {
        "sway"
    }

    fn run(self: Box<Self>, tx: Sender<Event>) {
        let Some(path) = self.socket.clone() else {
            // Non c'è Sway (altro compositor o sessione senza variabile): il QML resta sul controllo periodico.
            let _ = tx.send(Event::Error("sway".into(), "SWAYSOCK non impostata".into()));
            return;
        };
        let mut failing = false;
        loop {
            let mut delivered = false;
            let end = self.session(&path, &tx, &mut delivered);
            if delivered {
                failing = false; // la sessione era partita: un nuovo guasto va segnalato di nuovo
            }
            match end {
                End::Quit => return,
                End::Lost(why) => {
                    // L'errore si segnala una volta per serie di tentativi; lo stato torna vuoto, così a Vela non resta un elenco vecchio.
                    if !failing {
                        failing = true;
                        if tx.send(Event::Error("sway".into(), why)).is_err() || tx.send(Event::State("sway".into(), empty_state())).is_err() {
                            return;
                        }
                    }
                }
            }
            sleep(self.retry);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::net::UnixListener;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::mpsc;
    use std::thread;

    static N: AtomicUsize = AtomicUsize::new(0);

    fn sock_path() -> PathBuf {
        // i percorsi dei socket Unix sono corti (108 byte): si usa la cartella di runtime dell'utente se c'è
        let dir = std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
        dir.join(format!("vela-sway-test-{}-{}.sock", std::process::id(), N.fetch_add(1, Ordering::SeqCst)))
    }

    const KBD: &str = r#"[{"identifier":"1:1:kbd","name":"AT keyboard","type":"keyboard","xkb_layout_names":["Italian","English (US)"],"xkb_active_layout_index":0,"libinput":{"send_events":"enabled"}},
        {"identifier":"2:2:tp","name":"Touchpad","type":"touchpad","libinput":{"send_events":"disabled_on_external_mouse"}}]"#;

    /// Albero ridotto: un workspace con un contenitore a schede che contiene due finestre, la seconda col focus.
    const TREE_TABBED: &str = r#"{"type":"root","focused":false,"nodes":[{"type":"output","focused":false,"nodes":[
        {"type":"workspace","layout":"splith","focused":false,"nodes":[
          {"type":"con","layout":"tabbed","focused":false,"nodes":[
            {"type":"con","layout":"none","focused":false,"nodes":[]},
            {"type":"con","layout":"none","focused":true,"nodes":[]}]}],"floating_nodes":[]}]}]}"#;

    fn layout_of(tree: &str) -> &'static str {
        focus_layout(&json::parse(tree).unwrap())
    }

    #[test]
    fn layout_del_contenitore_col_focus() {
        assert_eq!(layout_of(TREE_TABBED), "tabbed");
        assert_eq!(layout_of(&TREE_TABBED.replace("\"tabbed\"", "\"stacked\"")), "stacking");
        assert_eq!(layout_of(&TREE_TABBED.replace("\"tabbed\"", "\"splitv\"")), "splitv");
        assert_eq!(layout_of(&TREE_TABBED.replace("\"tabbed\"", "\"qualcosa\"")), "", "valore sconosciuto");
        // finestra direttamente nel workspace: conta il workspace
        let in_ws = r#"{"type":"root","nodes":[{"type":"workspace","layout":"splitv","nodes":[{"type":"con","layout":"none","focused":true,"nodes":[]}],"floating_nodes":[]}]}"#;
        assert_eq!(layout_of(in_ws), "splitv");
        // workspace vuoto col focus: il suo layout
        let empty = r#"{"type":"root","nodes":[{"type":"workspace","layout":"splith","focused":true,"nodes":[],"floating_nodes":[]}]}"#;
        assert_eq!(layout_of(empty), "splith");
        // contenitore (non una finestra) col focus: il suo layout, non quello del genitore
        let cont = r#"{"type":"root","nodes":[{"type":"workspace","layout":"splith","nodes":[{"type":"con","layout":"stacked","focused":true,"nodes":[{"type":"con","layout":"none","nodes":[]}]}]}]}"#;
        assert_eq!(layout_of(cont), "stacking");
    }

    #[test]
    fn finestra_flottante_e_senza_focus() {
        let floating = r#"{"type":"root","nodes":[{"type":"workspace","layout":"splith","nodes":[],"floating_nodes":[{"type":"floating_con","layout":"none","focused":true,"nodes":[]}]}]}"#;
        assert_eq!(layout_of(floating), "floating");
        assert_eq!(layout_of(r#"{"type":"root","nodes":[]}"#), "");
        assert_eq!(layout_of(r#"[1,2]"#), "");
        assert_eq!(layout_of(r#"{"focused":"si"}"#), "", "focused non booleano");
    }

    #[test]
    fn albero_troppo_profondo_non_fa_danni() {
        let mut t = String::from(r#"{"type":"con","layout":"none","focused":true,"nodes":[]}"#);
        for _ in 0..200 {
            t = format!(r#"{{"type":"con","layout":"splith","nodes":[{t}],"floating_nodes":[]}}"#);
        }
        let v = Value::Obj(vec![]);
        assert_eq!(focus_layout(&v), "");
        // il parser rifiuta già l'annidamento eccessivo: l'esito è un errore, non un crollo
        assert!(json::parse(&t).is_err());
    }

    #[test]
    fn quali_eventi_fanno_rileggere_il_layout() {
        let ev = |k: u32, b: &str| layout_event(k, b.as_bytes());
        assert!(ev(EVENT_WINDOW, r#"{"change":"focus"}"#));
        assert!(ev(EVENT_WINDOW, r#"{"change":"floating"}"#));
        assert!(!ev(EVENT_WINDOW, r#"{"change":"title"}"#), "i titoli cambiano di continuo");
        assert!(ev(EVENT_WORKSPACE, r#"{"change":"focus"}"#));
        assert!(!ev(EVENT_WORKSPACE, r#"{"change":"reload"}"#));
        assert!(ev(EVENT_BINDING, r#"{"change":"run","binding":{"command":"layout toggle split"}}"#));
        assert!(!ev(EVENT_BINDING, r#"{"change":"run","binding":{"command":"exec foot"}}"#));
        assert!(!ev(EVENT_BINDING, r#"{"change":"run"}"#));
        assert!(!ev(EVENT_INPUT, r#"{"change":"focus"}"#), "gli input hanno la loro strada");
        assert!(!ev(EVENT_WINDOW, "non json"));
    }

    #[test]
    fn fotogramma_andata_e_ritorno() {
        let f = encode_frame(100, b"abc");
        assert_eq!(&f[..6], b"i3-ipc");
        let (k, b) = read_frame(&mut &f[..]).unwrap();
        assert_eq!((k, b.as_slice()), (100, &b"abc"[..]));
    }

    #[test]
    fn fotogrammi_non_validi_vengono_rifiutati() {
        let mut bad = encode_frame(1, b"x");
        bad[0] = b'X';
        assert!(read_frame(&mut &bad[..]).is_err(), "magic sbagliato");
        let mut big = encode_frame(1, b"");
        big[6..10].copy_from_slice(&(MAX_PAYLOAD + 1).to_ne_bytes());
        assert!(read_frame(&mut &big[..]).is_err(), "troppo grande");
        let cut = encode_frame(1, b"abcdef");
        assert!(read_frame(&mut &cut[..cut.len() - 2]).is_err(), "troncato");
        assert!(read_frame(&mut &cut[..5]).is_err(), "intestazione troncata");
    }

    #[test]
    fn stato_dagli_input() {
        let st = inputs_list(&json::parse(KBD).unwrap()).unwrap();
        let ins = st.as_array().unwrap();
        assert_eq!(ins.len(), 2);
        assert_eq!(ins[0].get("type").unwrap().as_str(), Some("keyboard"));
        assert_eq!(ins[0].get("layouts").unwrap().as_array().unwrap().len(), 2);
        assert_eq!(ins[0].get("send_events").unwrap().as_str(), Some("enabled"));
        assert_eq!(ins[1].get("send_events").unwrap().as_str(), Some("disabled_on_external_mouse"));
        assert_eq!(ins[1].get("layouts").unwrap().as_array().unwrap().len(), 0);
        assert_eq!(ins[1].get("layout_index").unwrap().as_i64(), Some(0));
    }

    #[test]
    fn stato_con_dati_ostili() {
        let many: Vec<String> = (0..200).map(|i| format!(r#"{{"identifier":"{i}","name":"{}","type":"keyboard","xkb_layout_names":["a","b","c","d","e","f","g","h","i","l","m","n","o","p","q","r","s","t"],"xkb_active_layout_index":999999}}"#, "x".repeat(1000))).collect();
        let st = inputs_list(&json::parse(&format!("[{}]", many.join(","))).unwrap()).unwrap();
        let ins = st.as_array().unwrap();
        assert_eq!(ins.len(), MAX_INPUTS);
        assert!(ins[0].get("name").unwrap().as_str().unwrap().chars().count() <= crate::proto::MAX_STR);
        assert_eq!(ins[0].get("layouts").unwrap().as_array().unwrap().len(), MAX_LAYOUTS);
        assert_eq!(ins[0].get("layout_index").unwrap().as_i64(), Some(0), "indice fuori misura scartato");
        assert!(inputs_list(&json::parse(r#"{"x":1}"#).unwrap()).is_err());
        assert!(inputs_list(&json::parse(r#"[1,"a",null,{"type":5}]"#).unwrap()).is_ok());
    }

    /// Finto Sway: accetta due tipi di connessione (abbonamento e domande). `replies` sono le risposte a `get_inputs`,
    /// una per domanda; dopo la prima, manda un evento input sull'abbonamento.
    fn fake_sway(path: PathBuf, replies: Vec<&'static str>) -> thread::JoinHandle<()> {
        let l = UnixListener::bind(&path).unwrap();
        thread::spawn(move || {
            let mut sub: Option<UnixStream> = None;
            let mut asked = 0;
            for conn in l.incoming() {
                let mut c = conn.unwrap();
                let (k, _) = match read_frame(&mut c) {
                    Ok(x) => x,
                    Err(_) => continue,
                };
                if k == SUBSCRIBE {
                    c.write_all(&encode_frame(SUBSCRIBE, br#"{"success": true}"#)).unwrap();
                    sub = Some(c);
                } else if k == GET_TREE {
                    c.write_all(&encode_frame(GET_TREE, TREE_TABBED.as_bytes())).unwrap();
                } else if k == GET_INPUTS {
                    c.write_all(&encode_frame(GET_INPUTS, replies[asked.min(replies.len() - 1)].as_bytes())).unwrap();
                    asked += 1;
                    if asked == 1 {
                        // un evento di tipo diverso (da ignorare) e poi uno input
                        thread::sleep(Duration::from_millis(50));
                        let s = sub.as_mut().unwrap();
                        s.write_all(&encode_frame(0x8000_0000, b"{}")).unwrap();
                        s.write_all(&encode_frame(EVENT_INPUT, br#"{"change":"xkb_layout"}"#)).unwrap();
                    }
                    if asked >= replies.len() {
                        return;
                    }
                }
            }
        })
    }

    #[test]
    fn il_modulo_manda_lo_stato_e_lo_aggiorna_a_ogni_evento() {
        let path = sock_path();
        let second = r#"[{"identifier":"1:1:kbd","name":"AT keyboard","type":"keyboard","xkb_layout_names":["Italian","English (US)"],"xkb_active_layout_index":1}]"#;
        let srv = fake_sway(path.clone(), vec![KBD, second]);
        let m = Box::new(Sway { socket: Some(path.clone()), retry: Duration::from_millis(50), settle: Duration::from_millis(5) });
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || m.run(tx));
        let get = || match rx.recv_timeout(Duration::from_secs(3)).expect("nessun evento") {
            Event::State(n, v) => {
                assert_eq!(n, "sway");
                v
            }
            Event::Error(_, e) => panic!("errore: {e}"),
            Event::Quit => panic!("quit"),
        };
        let a = get();
        assert_eq!(a.get("inputs").unwrap().as_array().unwrap().len(), 2);
        assert_eq!(a.get("layout").unwrap().as_str(), Some("tabbed"));
        let b = get();
        let ins = b.get("inputs").unwrap().as_array().unwrap();
        assert_eq!(ins.len(), 1);
        assert_eq!(ins[0].get("layout_index").unwrap().as_i64(), Some(1));
        srv.join().unwrap();
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn senza_socket_il_modulo_segnala_e_finisce() {
        let m = Box::new(Sway { socket: None, retry: Duration::from_millis(10), settle: Duration::from_millis(1) });
        let (tx, rx) = mpsc::channel();
        let h = thread::spawn(move || m.run(tx));
        match rx.recv_timeout(Duration::from_secs(2)).unwrap() {
            Event::Error(m, _) => assert_eq!(m, "sway"),
            _ => panic!("atteso un errore"),
        }
        h.join().unwrap();
    }

    #[test]
    fn sway_assente_errore_una_volta_e_stato_vuoto() {
        let path = sock_path(); // nessun server in ascolto
        let m = Box::new(Sway { socket: Some(path), retry: Duration::from_millis(20), settle: Duration::from_millis(1) });
        let (tx, rx) = mpsc::channel();
        thread::spawn(move || m.run(tx));
        assert!(matches!(rx.recv_timeout(Duration::from_secs(2)).unwrap(), Event::Error(..)));
        match rx.recv_timeout(Duration::from_secs(2)).unwrap() {
            Event::State(_, v) => assert_eq!(v.get("inputs").unwrap().as_array().unwrap().len(), 0),
            _ => panic!("atteso lo stato vuoto"),
        }
        assert!(rx.recv_timeout(Duration::from_millis(200)).is_err(), "nessun errore ripetuto durante i tentativi");
    }
}
