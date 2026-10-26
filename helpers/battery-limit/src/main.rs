// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Helper di Vela per le soglie di carica della batteria (D-032, riscritto in Rust: D-038).
//!
//! ```text
//! battery-limit status          stato in righe chiave=valore (non serve root)
//! battery-limit limit on|off    limite attivo (soglie 75/80, o il limite fisso del firmware) o disattivo; resta dopo il riavvio
//! battery-limit full start      carica piena una tantum finché la batteria è piena, poi ripristina
//! battery-limit full stop       annulla la carica piena e ripristina subito
//! battery-limit boot            riapplica la scelta all'avvio (regola udev); non fa nulla se non è mai stata fatta
//! ```
//! (`__watch` e `__boot-wait` sono interni: li lancia l'helper stesso e da fuori sono rifiutati.)
//!
//! Due tipi di batteria: a soglie (`charge_control_*_threshold`) o con limite fisso (`charge_types`: `Long_Life`).
//! Gira come root tramite pkexec (regola polkit per il gruppo wheel). Accetta SOLO queste parole e nessun valore
//! numerico dall'esterno: le soglie vengono da `/etc/vela/battery-limit.conf`, scritto da root.
//!
//! Prova senza root: `VELA_BATTERY_TEST_DIR=/cartella` (con `sys/BAT0/…`) viene ignorata se si è root.
#![forbid(unsafe_code)]

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{self, Command, Stdio};
use std::thread::sleep;
use std::time::{Duration, Instant};

const DEFAULT_LIMIT_START: u32 = 75;
const DEFAULT_LIMIT_END: u32 = 80;
const FULL_START: u32 = 99;
const FULL_END: u32 = 100;

/// Tempi del sorvegliante della carica piena.
struct WatchParams {
    poll: Duration,
    timeout: Duration,        // oltre 6 ore qualcosa non va
    unplugged_giveup: Duration,
}

impl WatchParams {
    fn standard() -> Self {
        WatchParams {
            poll: Duration::from_secs(30),
            timeout: Duration::from_secs(6 * 3600),
            unplugged_giveup: Duration::from_secs(2 * 3600),
        }
    }
}

/// Percorsi di sistema, o una cartella di prova (solo se non si è root).
struct Paths {
    sys: PathBuf,
    conf: PathBuf,        // facoltativo: LIMIT_START=… LIMIT_END=… (solo root)
    state_dir: PathBuf,
    choice: PathBuf,      // contiene "on" oppure "off"
    run_dir: PathBuf,
    full_state: PathBuf,  // pid del sorvegliante
}

impl Paths {
    fn new(sys: &str, conf_dir: &str, state_dir: &str, run_dir: &str) -> Self {
        let state_dir = PathBuf::from(state_dir);
        let run_dir = PathBuf::from(run_dir);
        Paths {
            sys: PathBuf::from(sys),
            conf: Path::new(conf_dir).join("battery-limit.conf"),
            choice: state_dir.join("battery-limit"),
            state_dir,
            full_state: run_dir.join("vela-battery-full"),
            run_dir,
        }
    }
    fn system() -> Self {
        Paths::new("/sys/class/power_supply", "/etc/vela", "/var/lib/vela", "/run")
    }
    fn under(root: &Path) -> Self {
        let r = |d: &str| root.join(d).to_string_lossy().into_owned();
        Paths::new(&r("sys"), &r("etc"), &r("var"), &r("run"))
    }
}

#[derive(Clone, Copy, PartialEq, Debug)]
enum Mode {
    /// Soglie di carica regolabili (ThinkPad e simili).
    Thresholds,
    /// Limite fisso del firmware, solo acceso/spento (IdeaPad e simili).
    Fixed,
}

impl Mode {
    fn name(self) -> &'static str {
        match self {
            Mode::Thresholds => "thresholds",
            Mode::Fixed => "fixed",
        }
    }
}

struct Battery {
    dir: PathBuf,
    mode: Mode,
}

// --- lettura ------------------------------------------------------------------------------

/// Contenuto di un file senza spazi ai bordi; vuoto se manca o non è leggibile.
fn read(p: &Path) -> String {
    fs::read_to_string(p).map(|s| s.trim().to_string()).unwrap_or_default()
}

/// Solo cifre, nessun segno: i pid e i valori numerici passano di qui.
fn digits(s: &str) -> Option<u64> {
    if s.is_empty() || !s.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    s.parse().ok()
}

/// Valore di soglia: cifre, da 0 a 100.
fn num(s: &str) -> Option<u32> {
    digits(s).filter(|&n| n <= 100).map(|n| n as u32)
}

/// Elenco ordinato delle voci di una cartella il cui nome comincia con uno dei prefissi.
fn entries_with_prefix(dir: &Path, prefixes: &[&str]) -> Vec<PathBuf> {
    let mut v: Vec<PathBuf> = fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .filter(|e| {
            let n = e.file_name();
            let n = n.to_string_lossy();
            prefixes.iter().any(|p| n.starts_with(p))
        })
        .map(|e| e.path())
        .collect();
    v.sort();
    v
}

/// Prima batteria controllabile: prima quelle a soglie, poi quelle con limite fisso.
fn detect(sys: &Path) -> Option<Battery> {
    let bats = entries_with_prefix(sys, &["BAT"]);
    if let Some(d) = bats.iter().find(|d| d.join("charge_control_end_threshold").exists()) {
        return Some(Battery { dir: d.clone(), mode: Mode::Thresholds });
    }
    bats.iter()
        .find(|d| read(&d.join("charge_types")).contains("Long_Life"))
        .map(|d| Battery { dir: d.clone(), mode: Mode::Fixed })
}

/// Il kernel mostra il tipo selezionato tra parentesi quadre: "[Standard] Long_Life".
fn selected_charge_type(text: &str) -> String {
    let t = text.trim();
    if let (Some(a), Some(b)) = (t.find('['), t.find(']')) {
        if a < b {
            let inner = &t[a + 1..b];
            if !inner.is_empty() && inner.bytes().all(|c| c.is_ascii_alphabetic() || c == b'_') {
                return inner.to_string();
            }
        }
    }
    t.to_string()
}

/// Valori del limite: quelli di default, o quelli del file di root se sono numeri coerenti.
fn limits_from_conf(path: &Path) -> (u32, u32) {
    let text = read(path);
    let first = |key: &str| {
        text.lines()
            .filter_map(|l| l.strip_prefix(key))
            .next()
            .and_then(num)
    };
    match (first("LIMIT_START="), first("LIMIT_END=")) {
        (Some(s), Some(e)) if s < e => (s, e),
        _ => (DEFAULT_LIMIT_START, DEFAULT_LIMIT_END),
    }
}

// --- stato e azioni -----------------------------------------------------------------------

struct Ctx {
    paths: Paths,
    limit_start: u32,
    limit_end: u32,
    bat: Option<Battery>,
}

impl Ctx {
    fn load(paths: Paths) -> Self {
        let (limit_start, limit_end) = limits_from_conf(&paths.conf);
        let bat = detect(&paths.sys);
        Ctx { paths, limit_start, limit_end, bat }
    }

    fn choice(&self) -> String {
        read(&self.paths.choice)
    }

    /// Scrive il valore e il fine riga, come `echo valore > file`.
    fn put(path: &Path, value: &str) -> Result<(), String> {
        fs::write(path, format!("{value}\n")).map_err(|e| format!("scrittura di {} fallita: {e}", path.display()))
    }

    /// Scrive le soglie. L'EC rifiuta start > end: salendo si alza prima il tetto, scendendo prima il pavimento.
    /// Se la batteria non ha la soglia di inizio (solo end), si scrive solo quella.
    fn write_thresholds(&self, bat: &Battery, start: u32, end: u32) -> Result<(), String> {
        let end_f = bat.dir.join("charge_control_end_threshold");
        let start_f = bat.dir.join("charge_control_start_threshold");
        if !start_f.exists() {
            return Self::put(&end_f, &end.to_string());
        }
        let cur_end: u32 = read(&end_f).parse().unwrap_or(0);
        if end >= cur_end {
            Self::put(&end_f, &end.to_string())?;
            Self::put(&start_f, &start.to_string())
        } else {
            Self::put(&start_f, &start.to_string())?;
            Self::put(&end_f, &end.to_string())
        }
    }

    fn charge_type(&self, bat: &Battery) -> String {
        selected_charge_type(&read(&bat.dir.join("charge_types")))
    }

    /// Limite acceso o spento, a prescindere dal modo della batteria.
    fn set_limited(&self, bat: &Battery, on: bool) -> Result<(), String> {
        match (bat.mode, on) {
            (Mode::Fixed, true) => Self::put(&bat.dir.join("charge_types"), "Long_Life"),
            (Mode::Fixed, false) => Self::put(&bat.dir.join("charge_types"), "Standard"),
            (Mode::Thresholds, true) => self.write_thresholds(bat, self.limit_start, self.limit_end),
            (Mode::Thresholds, false) => self.write_thresholds(bat, 0, 100),
        }
    }

    /// Carica piena una tantum: nessun limite e, a soglie, la soglia di inizio alta perché riparta subito.
    fn set_full(&self, bat: &Battery) -> Result<(), String> {
        match bat.mode {
            Mode::Fixed => Self::put(&bat.dir.join("charge_types"), "Standard"),
            Mode::Thresholds => self.write_thresholds(bat, FULL_START, FULL_END),
        }
    }

    /// Stato voluto in questo momento secondo la scelta salvata.
    fn apply_choice(&self, bat: &Battery) -> Result<(), String> {
        self.set_limited(bat, self.choice() == "on")
    }

    /// Vero se la batteria è limitata adesso.
    fn is_limited(&self, bat: &Battery) -> bool {
        match bat.mode {
            Mode::Fixed => self.charge_type(bat) == "Long_Life",
            Mode::Thresholds => read(&bat.dir.join("charge_control_end_threshold")) != "100",
        }
    }

    fn full_pid(&self) -> Option<u64> {
        digits(&read(&self.paths.full_state)).filter(|&p| p > 1)
    }

    /// Il sorvegliante è vivo solo se il pid esiste ed è davvero un nostro `__watch`: un pid riciclato dopo un
    /// arresto sporco non deve mai diventare il bersaglio di un `kill` fatto da root.
    fn full_alive(&self) -> bool {
        let Some(pid) = self.full_pid() else { return false };
        match fs::read(format!("/proc/{pid}/cmdline")) {
            Ok(raw) => raw.split(|&b| b == 0).any(|a| a == b"__watch"),
            Err(_) => false,
        }
    }

    fn status_text(&self) -> String {
        let Some(bat) = &self.bat else { return "supported=0\n".to_string() };
        let name = bat.dir.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        let mut s = String::from("supported=1\n");
        s += &format!("battery={name}\nmode={}\n", bat.mode.name());
        s += &format!("limited={}\n", u8::from(self.is_limited(bat)));
        if bat.mode == Mode::Thresholds {
            s += &format!("start={}\n", read(&bat.dir.join("charge_control_start_threshold")));
            s += &format!("end={}\n", read(&bat.dir.join("charge_control_end_threshold")));
            s += &format!("limit_start={}\nlimit_end={}\n", self.limit_start, self.limit_end);
        }
        s += &format!("choice={}\n", self.choice());
        s += &format!("full={}\n", u8::from(self.full_alive()));
        s
    }
}

// --- comandi ------------------------------------------------------------------------------

fn limit(ctx: &Ctx, bat: &Battery, arg: &str) -> Result<(), String> {
    if arg != "on" && arg != "off" {
        return Err("uso: limit on|off".into());
    }
    save_choice(ctx, arg)?;
    // Durante la carica piena le soglie restano 99/100: la scelta si applica al termine.
    if ctx.full_alive() {
        return Ok(());
    }
    ctx.apply_choice(bat).map_err(|_| "scrittura delle soglie fallita.".to_string())
}

/// Salva la scelta ("on"|"off"). Deve poter essere letta senza root (la legge `status` lanciato dalla shell);
/// pkexec parte con umask 077: i permessi si impostano a mano.
fn save_choice(ctx: &Ctx, value: &str) -> Result<(), String> {
    fs::create_dir_all(&ctx.paths.state_dir).map_err(|e| format!("cartella di stato: {e}"))?;
    chmod(&ctx.paths.state_dir, 0o755)?;
    Ctx::put(&ctx.paths.choice, value)?;
    chmod(&ctx.paths.choice, 0o644)
}

fn chmod(p: &Path, mode: u32) -> Result<(), String> {
    fs::set_permissions(p, fs::Permissions::from_mode(mode)).map_err(|e| format!("permessi di {}: {e}", p.display()))
}

fn ac_online(sys: &Path) -> bool {
    entries_with_prefix(sys, &["AC", "ADP"]).iter().any(|a| read(&a.join("online")) == "1")
}

/// Sorvegliante staccato: finita la carica (o scaduto un limite di tempo) ripristina la scelta salvata.
fn watch(ctx: &Ctx, bat: &Battery, p: &WatchParams) -> Result<(), String> {
    fs::create_dir_all(&ctx.paths.run_dir).map_err(|e| format!("cartella di stato: {e}"))?;
    Ctx::put(&ctx.paths.full_state, &process::id().to_string())?;
    chmod(&ctx.paths.full_state, 0o644)?;
    let started = Instant::now();
    let mut unplugged_at: Option<Instant> = None;
    loop {
        sleep(p.poll);
        let cap: u32 = read(&bat.dir.join("capacity")).parse().unwrap_or(0);
        let st = read(&bat.dir.join("status"));
        let now = Instant::now();
        if !ac_online(&ctx.paths.sys) {
            let since = *unplugged_at.get_or_insert(now);
            if now.duration_since(since) >= p.unplugged_giveup {
                break;
            }
            continue;
        }
        unplugged_at = None;
        // "Full" o 100%; l'EC a volte si ferma a 97-99 con "Not charging".
        if st == "Full" || cap >= 100 || (cap >= 97 && st == "Not charging") {
            break;
        }
        if now.duration_since(started) >= p.timeout {
            break;
        }
    }
    let r = ctx.apply_choice(bat);
    let _ = fs::remove_file(&ctx.paths.full_state);
    r
}

/// Lancia un'altra copia di questo programma staccata dal chiamante (nuova sessione se c'è `setsid`).
fn spawn_detached(arg: &str) -> bool {
    let Ok(exe) = std::env::current_exe() else { return false };
    let quiet = |c: &mut Command| {
        c.stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null());
    };
    let mut c = Command::new("setsid");
    c.arg(&exe).arg(arg).env(INTERNAL_ENV, "1");
    quiet(&mut c);
    if c.spawn().is_ok() {
        return true;
    }
    let mut c = Command::new(&exe);
    c.arg(arg).env(INTERNAL_ENV, "1").process_group(0);
    quiet(&mut c);
    c.spawn().is_ok()
}

fn full(ctx: &Ctx, bat: &Battery, arg: &str) -> Result<(), String> {
    match arg {
        "start" => {
            if ctx.full_alive() {
                return Err("carica piena già in corso.".into());
            }
            if !ctx.is_limited(bat) && ctx.choice() != "on" {
                return Err("il limite è già disattivo: niente da fare.".into());
            }
            // Limite già presente ma scelta mai fatta (firmware, regola udev): a fine carica deve tornare quello, non "off".
            if ctx.choice().is_empty() {
                save_choice(ctx, "on")?;
            }
            fs::create_dir_all(&ctx.paths.run_dir).map_err(|e| format!("cartella di stato: {e}"))?;
            ctx.set_full(bat).map_err(|_| "scrittura fallita.".to_string())?;
            // Il sorvegliante gira staccato: ripristina da solo ore dopo, senza terminale né password.
            // Il pid lo scrive il sorvegliante stesso (setsid può fare un fork) e qui lo si aspetta.
            let started = spawn_detached("__watch");
            for _ in 0..20 {
                if ctx.full_alive() {
                    return Ok(());
                }
                sleep(Duration::from_millis(100));
            }
            let _ = ctx.apply_choice(bat);
            Err(if started { "il sorvegliante non è partito: soglie ripristinate." } else { "impossibile avviare il sorvegliante: soglie ripristinate." }.into())
        }
        "stop" => {
            let Some(pid) = ctx.full_pid().filter(|_| ctx.full_alive()) else {
                return Err("nessuna carica piena in corso.".into());
            };
            let _ = Command::new("kill").arg(pid.to_string()).stderr(Stdio::null()).status();
            let _ = fs::remove_file(&ctx.paths.full_state);
            ctx.apply_choice(bat).map_err(|_| "ripristino fallito.".to_string())
        }
        _ => Err("uso: full start|stop".into()),
    }
}

/// All'avvio il kernel può registrare gli attributi dopo l'evento udev: se la batteria non c'è ancora, si riprova in coda.
fn boot(ctx: &Ctx) {
    if ctx.choice().is_empty() {
        return;
    }
    match &ctx.bat {
        Some(bat) => {
            let _ = ctx.apply_choice(bat);
        }
        None => {
            spawn_detached("__boot-wait");
        }
    }
}

fn boot_wait(paths: impl Fn() -> Paths) {
    for _ in 0..20 {
        sleep(Duration::from_secs(3));
        let ctx = Ctx::load(paths());
        if let Some(bat) = &ctx.bat {
            if ctx.apply_choice(bat).is_ok() {
                return;
            }
        }
    }
}

// --- ingresso -----------------------------------------------------------------------------

/// Utente effettivo dal kernel (`Uid: reale effettivo salvato fs`). Se non si riesce a leggere si presume root:
/// è la scelta prudente, perché root ignora la cartella di prova.
fn is_root() -> bool {
    let status = fs::read_to_string("/proc/self/status").unwrap_or_default();
    status
        .lines()
        .find_map(|l| l.strip_prefix("Uid:"))
        .and_then(|rest| rest.split_whitespace().nth(1).map(str::to_string))
        .map_or(true, |euid| euid == "0")
}

fn test_dir() -> Option<PathBuf> {
    if is_root() {
        return None;
    }
    std::env::var_os("VELA_BATTERY_TEST_DIR").filter(|v| !v.is_empty()).map(PathBuf::from)
}

fn paths() -> Paths {
    match test_dir() {
        Some(d) => Paths::under(&d),
        None => Paths::system(),
    }
}

/// Marcatore che l'helper mette nell'ambiente dei propri figli staccati. pkexec ripulisce l'ambiente di chi lo lancia, quindi
/// i sottocomandi interni non sono raggiungibili da un utente, nemmeno dal gruppo wheel autorizzato da polkit.
const INTERNAL_ENV: &str = "VELA_BATTERY_INTERNAL";

/// Sottocomandi che esistono solo per essere lanciati dall'helper stesso (sorvegliante e attesa all'avvio).
fn is_internal(args: &[&str]) -> bool {
    matches!(args, ["__watch"] | ["__boot-wait"])
}

fn die(msg: &str) -> ! {
    eprintln!("battery-limit: {msg}");
    process::exit(1);
}

const USAGE: &str = "uso: battery-limit status | limit on|off | full start|stop | boot";

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    let ctx = Ctx::load(paths());

    // Le modifiche chiedono root (o la cartella di prova) e una batteria controllabile.
    let need_root = |ctx: &Ctx| -> Result<(), String> {
        if !is_root() && test_dir().is_none() {
            return Err("serve root (pkexec).".into());
        }
        if ctx.bat.is_none() {
            return Err("questa batteria non ha un limite di carica controllabile.".into());
        }
        Ok(())
    };

    if is_internal(&args) && std::env::var_os(INTERNAL_ENV).is_none_or(|v| v != "1") {
        die("comando interno: non si lancia a mano.");
    }

    let result = match args.as_slice() {
        ["status"] => {
            print!("{}", ctx.status_text());
            Ok(())
        }
        ["limit", arg] => need_root(&ctx).and_then(|_| limit(&ctx, ctx.bat.as_ref().unwrap(), arg)),
        ["full", arg] => need_root(&ctx).and_then(|_| full(&ctx, ctx.bat.as_ref().unwrap(), arg)),
        ["boot"] => {
            boot(&ctx);
            Ok(())
        }
        ["__watch"] => match &ctx.bat {
            Some(bat) => watch(&ctx, bat, &WatchParams::standard()),
            None => Err("batteria non disponibile.".into()),
        },
        ["__boot-wait"] => {
            boot_wait(paths);
            Ok(())
        }
        _ => {
            eprintln!("{USAGE}");
            process::exit(2);
        }
    };
    if let Err(e) = result {
        die(&e);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    static N: AtomicUsize = AtomicUsize::new(0);

    /// Finto /sys, /etc, /var e /run in una cartella temporanea.
    struct Fake {
        root: PathBuf,
    }
    impl Fake {
        fn new() -> Self {
            let root = std::env::temp_dir().join(format!("vela-bl-{}-{}", process::id(), N.fetch_add(1, Ordering::SeqCst)));
            for d in ["sys", "etc", "var", "run"] {
                fs::create_dir_all(root.join(d)).unwrap();
            }
            Fake { root }
        }
        fn w(&self, rel: &str, content: &str) {
            let p = self.root.join(rel);
            fs::create_dir_all(p.parent().unwrap()).unwrap();
            fs::write(p, content).unwrap();
        }
        fn r(&self, rel: &str) -> String {
            read(&self.root.join(rel))
        }
        fn ctx(&self) -> Ctx {
            Ctx::load(Paths::under(&self.root))
        }
        fn thresholds(&self, start: &str, end: &str) {
            self.w("sys/BAT0/charge_control_start_threshold", start);
            self.w("sys/BAT0/charge_control_end_threshold", end);
        }
    }
    impl Drop for Fake {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    #[test]
    fn digits_e_num() {
        assert_eq!(digits("123"), Some(123));
        assert_eq!(digits(""), None);
        assert_eq!(digits("-1"), None);
        assert_eq!(digits("1 2"), None);
        assert_eq!(digits("99999999999999999999999"), None);
        assert_eq!(num("100"), Some(100));
        assert_eq!(num("101"), None);
    }

    #[test]
    fn tipo_di_carica_selezionato() {
        assert_eq!(selected_charge_type("[Standard] Long_Life\n"), "Standard");
        assert_eq!(selected_charge_type("Standard [Long_Life]"), "Long_Life");
        assert_eq!(selected_charge_type("Long_Life"), "Long_Life");
        assert_eq!(selected_charge_type("[bad value] x"), "[bad value] x");
    }

    #[test]
    fn senza_batteria_non_e_supportato() {
        let f = Fake::new();
        assert_eq!(f.ctx().status_text(), "supported=0\n");
    }

    #[test]
    fn soglie_acceso_e_spento_nei_due_versi() {
        let f = Fake::new();
        f.thresholds("0\n", "100\n");
        let ctx = f.ctx();
        let bat = ctx.bat.as_ref().unwrap();
        assert_eq!(bat.mode, Mode::Thresholds);
        ctx.set_limited(bat, true).unwrap();
        assert_eq!((f.r("sys/BAT0/charge_control_start_threshold"), f.r("sys/BAT0/charge_control_end_threshold")), ("75".into(), "80".into()));
        assert!(ctx.is_limited(bat));
        ctx.set_limited(bat, false).unwrap();
        assert_eq!((f.r("sys/BAT0/charge_control_start_threshold"), f.r("sys/BAT0/charge_control_end_threshold")), ("0".into(), "100".into()));
        assert!(!ctx.is_limited(bat));
    }

    #[test]
    fn solo_soglia_di_fine() {
        let f = Fake::new();
        f.w("sys/BAT0/charge_control_end_threshold", "100\n");
        let ctx = f.ctx();
        ctx.set_limited(ctx.bat.as_ref().unwrap(), true).unwrap();
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "80");
        assert!(!f.root.join("sys/BAT0/charge_control_start_threshold").exists());
    }

    #[test]
    fn limite_fisso() {
        let f = Fake::new();
        f.w("sys/BAT0/charge_types", "[Standard] Long_Life\n");
        let ctx = f.ctx();
        let bat = ctx.bat.as_ref().unwrap();
        assert_eq!(bat.mode, Mode::Fixed);
        assert!(!ctx.is_limited(bat));
        ctx.set_limited(bat, true).unwrap();
        assert_eq!(f.r("sys/BAT0/charge_types"), "Long_Life");
        assert!(ctx.is_limited(bat));
        ctx.set_full(bat).unwrap();
        assert_eq!(f.r("sys/BAT0/charge_types"), "Standard");
    }

    #[test]
    fn soglie_dal_file_di_root_solo_se_coerenti() {
        let f = Fake::new();
        f.thresholds("0", "100");
        f.w("etc/battery-limit.conf", "LIMIT_START=70\nLIMIT_END=85\n");
        assert_eq!((f.ctx().limit_start, f.ctx().limit_end), (70, 85));
        for bad in ["LIMIT_START=90\nLIMIT_END=80\n", "LIMIT_START=a\nLIMIT_END=80\n", "LIMIT_START=10\nLIMIT_END=101\n", "LIMIT_START=10\n"] {
            f.w("etc/battery-limit.conf", bad);
            assert_eq!((f.ctx().limit_start, f.ctx().limit_end), (75, 80), "{bad:?}");
        }
    }

    #[test]
    fn stato_a_soglie() {
        let f = Fake::new();
        f.thresholds("75", "80");
        f.w("var/battery-limit", "on\n");
        assert_eq!(
            f.ctx().status_text(),
            "supported=1\nbattery=BAT0\nmode=thresholds\nlimited=1\nstart=75\nend=80\nlimit_start=75\nlimit_end=80\nchoice=on\nfull=0\n"
        );
    }

    #[test]
    fn stato_a_limite_fisso() {
        let f = Fake::new();
        f.w("sys/BAT0/charge_types", "Standard [Long_Life]\n");
        assert_eq!(f.ctx().status_text(), "supported=1\nbattery=BAT0\nmode=fixed\nlimited=1\nchoice=\nfull=0\n");
    }

    #[test]
    fn il_comando_limit_salva_la_scelta_e_la_applica() {
        let f = Fake::new();
        f.thresholds("0", "100");
        let ctx = f.ctx();
        let bat = ctx.bat.as_ref().unwrap();
        limit(&ctx, bat, "on").unwrap();
        assert_eq!(f.r("var/battery-limit"), "on");
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "80");
        assert!(limit(&ctx, bat, "75").is_err());
        assert!(limit(&ctx, bat, "").is_err());
        limit(&ctx, bat, "off").unwrap();
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "100");
    }

    #[test]
    fn la_carica_piena_non_cancella_un_limite_preesistente() {
        // Limite messo da altro (firmware, regola udev) e scelta mai fatta con Vela: alla fine della carica piena
        // il limite deve tornare, non sparire. Qui il sorvegliante non parte (il binario di prova non lo sa fare):
        // `full start` ripristina subito, ed è lo stesso percorso di ripristino della fine carica.
        let f = Fake::new();
        f.thresholds("40", "80");
        let ctx = f.ctx();
        let bat = ctx.bat.as_ref().unwrap();
        assert_eq!(ctx.choice(), "");
        let _ = full(&ctx, bat, "start");
        assert_eq!(f.r("var/battery-limit"), "on", "la scelta va salvata prima di alzare le soglie");
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "80");
        assert!(ctx.is_limited(bat));
    }

    #[test]
    fn solo_i_sottocomandi_interni_richiedono_il_marcatore() {
        for a in ["__watch", "__boot-wait"] {
            assert!(is_internal(&[a]), "{a}");
        }
        for a in [&["status"][..], &["limit", "on"], &["full", "start"], &["boot"], &[]] {
            assert!(!is_internal(a), "{a:?}");
        }
    }

    #[test]
    fn il_sorvegliante_deve_essere_un_nostro_watch() {
        let f = Fake::new();
        f.thresholds("0", "100");
        // il nostro stesso pid esiste ma non è un `__watch`; un pid inesistente nemmeno
        f.w("run/vela-battery-full", &format!("{}\n", process::id()));
        assert!(!f.ctx().full_alive());
        f.w("run/vela-battery-full", "999999999\n");
        assert!(!f.ctx().full_alive());
        f.w("run/vela-battery-full", "1\n");
        assert!(!f.ctx().full_alive());
        f.w("run/vela-battery-full", "abc\n");
        assert!(!f.ctx().full_alive());
    }

    fn fast() -> WatchParams {
        WatchParams { poll: Duration::from_millis(5), timeout: Duration::from_secs(60), unplugged_giveup: Duration::from_millis(30) }
    }

    #[test]
    fn il_sorvegliante_ripristina_a_batteria_piena() {
        let f = Fake::new();
        f.thresholds("99", "100");
        f.w("var/battery-limit", "on\n");
        f.w("sys/BAT0/capacity", "100\n");
        f.w("sys/BAT0/status", "Full\n");
        f.w("sys/AC/online", "1\n");
        let ctx = f.ctx();
        watch(&ctx, ctx.bat.as_ref().unwrap(), &fast()).unwrap();
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "80");
        assert!(!f.root.join("run/vela-battery-full").exists());
    }

    #[test]
    fn il_sorvegliante_ripristina_anche_con_ec_fermo_a_97() {
        let f = Fake::new();
        f.thresholds("99", "100");
        f.w("var/battery-limit", "on\n");
        f.w("sys/BAT0/capacity", "97\n");
        f.w("sys/BAT0/status", "Not charging\n");
        f.w("sys/ADP1/online", "1\n");
        let ctx = f.ctx();
        watch(&ctx, ctx.bat.as_ref().unwrap(), &fast()).unwrap();
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "80");
    }

    #[test]
    fn il_sorvegliante_rinuncia_se_l_alimentatore_resta_staccato() {
        let f = Fake::new();
        f.thresholds("99", "100");
        f.w("var/battery-limit", "off\n");
        f.w("sys/BAT0/capacity", "50\n");
        f.w("sys/BAT0/status", "Discharging\n");
        f.w("sys/AC/online", "0\n");
        let ctx = f.ctx();
        watch(&ctx, ctx.bat.as_ref().unwrap(), &fast()).unwrap();
        assert_eq!(f.r("sys/BAT0/charge_control_start_threshold"), "0");
        assert_eq!(f.r("sys/BAT0/charge_control_end_threshold"), "100");
    }
}
