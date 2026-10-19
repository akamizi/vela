// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Limite di carica della batteria (D-032). Lo stato si legge con l'helper senza privilegi; le modifiche passano
// da `pkexec` e dall'helper di sistema (regola polkit per il gruppo wheel), che accetta solo poche parole fisse.
// Tutto resta nascosto (`supported` falso) sui portatili senza un limite controllabile.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    // --- stato letto dall'helper ---
    property bool supported: false
    property string mode: ""            // "thresholds" (soglie regolabili) | "fixed" (limite fisso del firmware)
    property bool limited: false        // limitata adesso
    property string choice: ""          // scelta salvata: "on" | "off" | "" (mai fatta)
    property bool full: false           // carica piena in corso
    property int start: 0
    property int end: 100
    property int limitEnd: 80
    property int limitStart: 75

    // --- operazione in corso ---
    property bool busy: false
    property string error: ""
    property bool helperInstalled: false

    readonly property string statusScript: Quickshell.shellDir + "/../helpers/battery-limit"
    readonly property string helper: Config.shell.battery.limitHelper
    // Il limite è "voluto" anche durante la carica piena (le soglie tornano da sole alla fine).
    readonly property bool wanted: full ? choice === "on" : limited

    function parse(text) {
        var kv = {};
        text.split("\n").forEach(function (l) { var i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1); });
        var wasFull = full;
        supported = kv.supported === "1";
        if (!supported) { mode = ""; full = false; return; }
        mode = kv.mode || "";
        limited = kv.limited === "1";
        choice = kv.choice || "";
        full = kv.full === "1";
        start = parseInt(kv.start) || 0;
        end = parseInt(kv.end) || 100;
        limitStart = parseInt(kv.limit_start) || 75;
        limitEnd = parseInt(kv.limit_end) || 80;
        // La carica piena è finita da sola (non per un annullamento fatto da qui): lo si dice.
        if (wasFull && !full && !cancelling) Quickshell.execDetached(["notify-send", "-a", "Vela", "-i", "battery-full", I18n.tr("Carica piena terminata"), I18n.tr("Il limite di carica è tornato com'era.")]);
        cancelling = false;
    }
    property bool cancelling: false

    function refresh() { if (!reader.running) reader.running = true; }

    Process {
        id: reader
        command: ["sh", root.statusScript, "status"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Process {
        command: ["sh", "-c", "test -x \"$1\"", "sh", root.helper]
        running: root.supported
        onExited: code => root.helperInstalled = (code === 0)
    }

    // Controlla all'avvio e poi con calma: non c'è niente da seguire a ogni secondo.
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Process {
        id: runner
        stderr: StdioCollector { id: runnerErr }
        onExited: code => {
            root.busy = false;
            if (code === 0) root.error = "";
            else if (code === 126 || code === 127) root.error = I18n.tr("Autorizzazione negata o helper non installato");
            else root.error = (runnerErr.text.trim().split("\n").pop() || I18n.tr("Operazione non riuscita")).replace(/^battery-limit:\s*/, "");
            root.refresh();
        }
    }
    function run(args) {
        if (!supported || busy || !helperInstalled) return;
        busy = true;
        error = "";
        runner.command = ["pkexec", helper].concat(args);
        runner.running = true;
    }

    function setLimit(on) { run(["limit", on ? "on" : "off"]); }
    function toggleLimit() { setLimit(!wanted); }
    function startFull() { run(["full", "start"]); }
    function stopFull() { cancelling = true; run(["full", "stop"]); }
    function toggleFull() { if (full) stopFull(); else startFull(); }
}
