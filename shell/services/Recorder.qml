// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Registratore dello schermo (senza audio): wf-recorder lanciato da Vela, l'area scelta con slurp. File rec-AAAAMMGG-HHMMSS.mp4 in
// <Video XDG>/Registrazioni. Codifica VA-API se il PC la offre (verificato con vainfo), altrimenti x264. Un solo tasto avvia e ferma:
// lo stesso comando ferma una registrazione in corso, qualunque ne sia il tipo. Se Vela muore, wf-recorder riceve SIGINT e chiude il file.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/reclib.js" as Rec
import "../core/userdirs.js" as UserDirs

Singleton {
    id: root

    // "idle" | "selecting" (slurp aperto) | "starting" | "recording" | "error"
    property string state: "idle"
    property string mode: ""                 // "screen" | "area"
    property string file: ""
    property string error: ""
    readonly property bool busy: state === "selecting" || state === "starting" || state === "recording"

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string userDirsPath: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/user-dirs.dirs"
    readonly property string render: "/dev/dri/renderD128"

    property string encoder: ""              // "" = non ancora verificato, poi "vaapi" | "software"
    property string geometry: ""
    property string outDir: ""
    property bool stopping: false

    function toggle(m) {
        if (state === "selecting") { slurp.signal(15); return; }      // secondo comando mentre si sceglie l'area = annulla
        if (state === "starting") return;
        if (state === "recording") { stop(); return; }
        start(m);
    }

    function start(m) {
        if (busy) return;
        if (m !== "screen" && m !== "area") return;
        mode = m; error = ""; file = ""; geometry = ""; stopping = false;
        if (m === "area") { state = "selecting"; slurp.running = true; }
        else { state = "starting"; dirsRead.running = true; }
    }

    function stop() {
        if (state === "selecting") { slurp.signal(15); return; }
        if (state !== "recording" || !recorder.running) return;
        stopping = true;
        recorder.signal(2);                  // SIGINT: wf-recorder chiude il file
        forceStop.restart();
    }

    function fail(msg) {
        state = "error"; error = msg;
        Quickshell.execDetached(["notify-send", "-a", "Vela", "-u", "critical", "-i", "dialog-error", I18n.tr("Registrazione"), msg]);
    }

    // 1. area: slurp scrive la geometria; Esc = niente (codice ≠ 0), non è un errore
    Process {
        id: slurp
        command: ["slurp"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.geometry = text.trim();
                if (root.geometry !== "") { root.state = "starting"; dirsRead.running = true; }
            }
        }
        onExited: code => { if (root.state === "selecting" && root.geometry === "") root.state = "idle"; }
    }

    // 2. cartella: Video XDG (o ~/Video, ~/Videos) + Registrazioni
    Process {
        id: dirsRead
        command: ["cat", root.userDirsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = UserDirs.userDir(text, root.home, "XDG_VIDEOS_DIR");
                // Gli argomenti sono separati: nessun nome di cartella passa per una shell. Prima riga: la cartella; poi vainfo (se serve).
                prep.command = ["sh", "-c",
                    'd=$1; if [ -z "$d" ]; then for c in "$2/Video" "$2/Videos"; do [ -d "$c" ] && d=$c && break; done; [ -n "$d" ] || d="$2/Video"; fi; ' +
                    'mkdir -p "$d/Registrazioni" || exit 1; printf "%s\\n" "$d/Registrazioni"; ' +
                    '[ "$4" = probe ] && [ -r "$3" ] && vainfo --display drm --device "$3" 2>/dev/null; exit 0',
                    "sh", v, root.home, root.render, root.encoder === "" ? "probe" : "skip"];
                prep.running = true;
            }
        }
    }

    // 3. cartella creata e (la prima volta) sonda VA-API, poi si lancia wf-recorder
    Process {
        id: prep
        stdout: StdioCollector {
            onStreamFinished: {
                var nl = text.indexOf("\n");
                if (nl < 0) { root.fail(I18n.tr("Impossibile creare la cartella delle registrazioni")); return; }
                root.outDir = text.slice(0, nl);
                if (root.encoder === "") root.encoder = Rec.vaapiOk(text.slice(nl + 1)) ? "vaapi" : "software";
                root.launch();
            }
        }
    }

    function launch() {
        file = outDir + "/" + Rec.fileName(new Date());
        var args = Rec.recorderArgs(mode, geometry, encoder, file, render);
        if (args.length === 0) { state = "idle"; return; }
        // setpriv: se Vela muore, wf-recorder riceve SIGINT e chiude bene il file.
        recorder.command = ["sh", "-c", 'if command -v setpriv >/dev/null; then exec setpriv --pdeathsig INT "$@"; else exec "$@"; fi', "sh", "wf-recorder"].concat(args);
        recorder.running = true;
        alive.restart();
    }

    Process {
        id: recorder
        onExited: code => {
            alive.stop(); forceStop.stop();
            if (root.stopping) {
                root.stopping = false; root.state = "idle";
                Quickshell.execDetached(["notify-send", "-a", "Vela", "-i", "media-record", I18n.tr("Registrazione salvata"), root.file]);
            } else if (root.state === "starting" || root.state === "recording") {
                root.fail(code === 127 ? I18n.tr("wf-recorder non è installato") : I18n.tr("wf-recorder si è fermato (codice %1)", code));
            }
        }
    }
    // Se dopo mezzo secondo wf-recorder è ancora vivo, la registrazione è partita.
    Timer {
        id: alive; interval: 500
        onTriggered: if (recorder.running && root.state === "starting") {
            root.state = "recording";
            Quickshell.execDetached(["notify-send", "-a", "Vela", "-i", "media-record", I18n.tr("Registrazione avviata"), root.file]);
        }
    }
    // SIGINT ignorato: dopo 5 secondi SIGTERM.
    Timer { id: forceStop; interval: 5000; onTriggered: if (recorder.running) recorder.signal(15) }
}
