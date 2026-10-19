// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Web radio: un solo flusso alla volta, riprodotto da un player esterno (mpv di default) lanciato da Vela.
// Le stazioni stanno in configurazione (radio.stations). Il processo è nostro: si ferma da qui, senza pkill.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    readonly property var stations: (Config.shell.radio.stations || []).filter(function (s) {
        return s && typeof s.name === "string" && s.name !== "" && validUrl(s.url);
    })
    // "stopped" | "starting" | "playing" | "error"
    property string state: "stopped"
    property string name: ""
    property string url: ""
    property string error: ""
    readonly property bool playing: state === "starting" || state === "playing"

    function validUrl(u) { return typeof u === "string" && /^(https?|rtmps?|rtsp|mms):\/\/\S+$/.test(u); }

    property var pending: null
    property bool stopping: false

    function play(station) {
        if (!station || !validUrl(station.url)) return;
        if (proc.running) { pending = station; stopping = true; proc.running = false; return; }
        start(station);
    }
    function stop() {
        pending = null;
        if (proc.running) { stopping = true; proc.running = false; }
        else { state = "stopped"; error = ""; }
        name = "";
    }
    function toggle(station) { if (playing && url === station.url) stop(); else play(station); }

    function start(station) {
        name = station.name; url = station.url; error = ""; state = "starting"; stopping = false;
        var base = Config.shell.radio.command;
        if (!Array.isArray(base) || base.length === 0) base = ["mpv", "--no-video", "--no-terminal"];
        // `--` impedisce che l'indirizzo sia preso per un'opzione; setpriv ferma il player se Vela muore.
        proc.command = ["sh", "-c", 'if command -v setpriv >/dev/null; then exec setpriv --pdeathsig TERM "$@"; else exec "$@"; fi', "sh"]
            .concat(base, ["--", station.url]);
        proc.running = true;
        confirm.restart();
    }

    Process {
        id: proc
        onExited: code => {
            confirm.stop();
            if (root.pending) { var p = root.pending; root.pending = null; root.start(p); return; }
            if (root.stopping) { root.stopping = false; root.state = "stopped"; return; }
            root.state = "error";
            root.error = code === 127 ? I18n.tr("player non trovato") : I18n.tr("stazione non raggiungibile");
        }
    }
    // Se dopo qualche secondo il player è ancora vivo, il flusso è partito.
    Timer { id: confirm; interval: 3000; onTriggered: if (proc.running && root.state === "starting") root.state = "playing" }
}
