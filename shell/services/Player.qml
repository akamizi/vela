// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Arbitro del player audio: un solo flusso alla volta, condiviso da Radio, Musica e Subsonic.
// Il player (mpv di default) è un processo nostro: si ferma da qui, senza pkill; se Vela muore, muore anche lui.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    // "stopped" | "starting" | "playing" | "error"
    property string state: "stopped"
    // "" | "radio" | "music" | "subsonic"
    property string kind: ""
    property string name: ""
    // Identifica ciò che suona: indirizzo della stazione, percorso della cartella o del brano, id dell'album o del brano
    property string key: ""
    property string error: ""
    readonly property bool playing: state === "starting" || state === "playing"

    // Uscita del player: wanted = fermato da noi (Stop o cambio di flusso), non un errore.
    signal exited(string kind, int code, bool wanted)

    property var pending: null
    property bool stopping: false
    // Il tipo del processo in corso: `kind` si azzera subito con Stop, ma chi ascolta `exited` deve sapere chi è uscito.
    property string runKind: ""

    // `args`: argomenti dopo il comando base (per esempio ["--", indirizzo] o ["--", file1, file2]).
    function play(kind, name, key, args) {
        var p = { kind: kind, name: name, key: key, args: args };
        if (proc.running) { pending = p; stopping = true; proc.running = false; return; }
        start(p);
    }
    function stop() {
        pending = null;
        if (proc.running) { stopping = true; proc.running = false; }
        else { state = "stopped"; error = ""; }
        name = ""; key = ""; kind = "";
    }

    function start(p) {
        kind = p.kind; runKind = p.kind; name = p.name; key = p.key; error = ""; state = "starting"; stopping = false;
        var base = Config.shell.radio.command;
        if (!Array.isArray(base) || base.length === 0) base = ["mpv", "--no-video", "--no-terminal"];
        // setpriv ferma il player se Vela muore.
        proc.command = ["sh", "-c", 'if command -v setpriv >/dev/null; then exec setpriv --pdeathsig TERM "$@"; else exec "$@"; fi', "sh"]
            .concat(base, p.args);
        proc.running = true;
        confirm.restart();
    }

    Process {
        id: proc
        onExited: code => {
            confirm.stop();
            var k = root.runKind, wanted = root.stopping;
            if (root.pending) { var p = root.pending; root.pending = null; root.exited(k, code, true); root.start(p); return; }
            if (root.stopping) { root.stopping = false; root.state = "stopped"; root.exited(k, code, true); return; }
            // Un brano o un album che finisce da solo (codice 0 dopo la conferma) non è un errore.
            if (code === 0 && root.state === "playing") { root.state = "stopped"; root.name = ""; root.key = ""; root.kind = ""; root.exited(k, code, false); return; }
            root.state = "error";
            root.error = code === 127 ? I18n.tr("player non trovato") : (k === "radio" ? I18n.tr("stazione non raggiungibile") : I18n.tr("riproduzione non riuscita"));
            root.exited(k, code, wanted);
        }
    }
    // Se dopo qualche secondo il player è ancora vivo, il flusso è partito.
    Timer { id: confirm; interval: 3000; onTriggered: if (proc.running && root.state === "starting") root.state = "playing" }
}
