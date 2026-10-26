// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// I sottocomandi interni (`__watch`, `__boot-wait`, `boot-retry`) non sono raggiungibili da fuori: pkexec ripulisce l'ambiente,
// quindi solo l'helper stesso, che lancia i propri figli con il marcatore, può chiamarli.
use std::fs;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

fn run_with_deadline(arg: &str, marker: bool) -> Option<std::process::ExitStatus> {
    let root = std::env::temp_dir().join(format!("vela-bl-int-{}-{}", std::process::id(), arg.trim_start_matches('_')));
    for d in ["sys/BAT0", "etc", "var", "run"] {
        fs::create_dir_all(root.join(d)).unwrap();
    }
    fs::write(root.join("sys/BAT0/charge_control_end_threshold"), "80\n").unwrap();
    let mut c = Command::new(env!("CARGO_BIN_EXE_battery-limit"));
    c.arg(arg).env("VELA_BATTERY_TEST_DIR", &root).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null());
    if marker {
        c.env("VELA_BATTERY_INTERNAL", "1");
    }
    let mut child = c.spawn().unwrap();
    let t = Instant::now();
    let st = loop {
        if let Some(st) = child.try_wait().unwrap() {
            break Some(st);
        }
        if t.elapsed() > Duration::from_secs(3) {
            let _ = child.kill();
            let _ = child.wait();
            break None;
        }
        std::thread::sleep(Duration::from_millis(50));
    };
    let _ = fs::remove_dir_all(&root);
    st
}

#[test]
fn senza_marcatore_i_sottocomandi_interni_sono_rifiutati() {
    for arg in ["__watch", "__boot-wait", "boot-retry"] {
        let st = run_with_deadline(arg, false);
        assert!(st.is_some_and(|s| !s.success()), "{arg} deve uscire subito con errore, senza marcatore");
    }
}

#[test]
fn il_comando_pubblico_status_non_richiede_il_marcatore() {
    assert!(run_with_deadline("status", false).is_some_and(|s| s.success()));
}
