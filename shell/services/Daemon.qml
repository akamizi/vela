// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Demone dati (D-039): processo figlio `vela-daemon` che manda righe JSON con lo stato di sistema.
// Questo servizio lo avvia, lo rilancia se esce e segnala quando i dati non sono più freschi; chi usa i dati
// controlla `ready(modulo)` e, se è falso, ripiega sul proprio controllo periodico. Il demone è di sola lettura.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    readonly property var cfg: Config.shell.daemon
    readonly property bool enabled: cfg.enabled === true
    readonly property int protocolVersion: 1
    readonly property int staleAfterMs: 15000          // il demone manda un tick ogni 5 s

    property bool installed: false
    property bool connected: false      // ricevuto un `hello` valido
    property bool fresh: false          // ricevuto un `tick` da meno di staleAfterMs
    property bool incompatible: false   // versione del protocollo diversa: non si rilancia
    property var modules: []
    property var states: ({})           // modulo -> ultimo stato
    property var errors: ({})           // modulo -> ultimo messaggio di errore
    property double lastTick: 0
    property int restarts: 0
    property int restartDelay: 1000

    signal moduleState(string module)

    // La configurazione si legge in modo asincrono: percorso e moduli possono cambiare dopo l'avvio.
    readonly property string command: String(cfg.command || "")
    readonly property string modulesArg: (cfg.modules || []).join(",")
    onCommandChanged: if (enabled && !proc.running) check.running = true
    onModulesArgChanged: if (proc.running) { reconfiguring = true; proc.running = false; }
    property bool reconfiguring: false

    // Vero se i dati del modulo sono utilizzabili adesso.
    function ready(module) {
        return connected && fresh && modules.indexOf(module) >= 0 && states[module] !== undefined;
    }

    function status() {
        return JSON.stringify({
            enabled: enabled, installed: installed, connected: connected, fresh: fresh, incompatible: incompatible,
            modules: modules, restarts: restarts, errors: errors
        });
    }

    // Un messaggio è una riga JSON; tutto ciò che arriva si tratta come dato non fidato.
    function handle(line) {
        if (line.length > 65536) return;
        var m;
        try { m = JSON.parse(line); } catch (e) { console.warn("[vela] demone: riga non valida"); return; }
        if (!m || typeof m.type !== "string") return;
        if (m.type === "hello") {
            if (m.v !== protocolVersion) {
                console.warn("[vela] demone: versione del protocollo " + m.v + " non supportata");
                incompatible = true;
                proc.running = false;
                return;
            }
            modules = Array.isArray(m.modules) ? m.modules.filter(function (x) { return typeof x === "string"; }) : [];
            states = ({});
            errors = ({});
            connected = true;
            fresh = true;
            lastTick = Date.now();
            restartDelay = 1000;
            console.log("[vela] demone connesso, moduli: " + (modules.join(", ") || "nessuno"));
        } else if (!connected) {
            return;
        } else if (m.type === "tick") {
            lastTick = Date.now();
            fresh = true;
        } else if (m.type === "state") {
            if (typeof m.module !== "string" || modules.indexOf(m.module) < 0) return;
            var s = Object.assign({}, states);
            s[m.module] = m.data;
            states = s;
            moduleState(m.module);
        } else if (m.type === "error") {
            if (typeof m.module !== "string") return;
            var e2 = Object.assign({}, errors);
            e2[m.module] = typeof m.message === "string" ? m.message.slice(0, 256) : "";
            errors = e2;
        }
    }

    // Si avvia solo se il binario è installato (un controllo, all'avvio di Vela).
    Process {
        id: check
        command: ["sh", "-c", "test -x \"$1\"", "sh", root.command]
        running: root.enabled
        onExited: code => {
            root.installed = (code === 0);
            if (root.installed) proc.running = true;
        }
    }

    Process {
        id: proc
        command: [root.command, "--modules", root.modulesArg]
        stdinEnabled: true          // Vela tiene aperto stdin: se Vela muore, il demone se ne accorge ed esce
        stdout: SplitParser { onRead: line => root.handle(line) }
        onStarted: root.lastTick = Date.now()
        onExited: (code, status) => {
            root.connected = false;
            root.fresh = false;
            if (root.reconfiguring) { root.reconfiguring = false; proc.running = true; return; }
            if (root.enabled && !root.incompatible) {
                root.restarts++;
                restart.interval = root.restartDelay;
                root.restartDelay = Math.min(30000, root.restartDelay * 2);
                restart.start();
            }
        }
    }
    Timer { id: restart; onTriggered: if (root.enabled && !proc.running) proc.running = true }

    // Se i tick si fermano (demone bloccato) i dati non sono più freschi e il processo viene fermato e rilanciato.
    Timer {
        interval: 5000
        running: proc.running
        repeat: true
        onTriggered: {
            if (Date.now() - root.lastTick > root.staleAfterMs) {
                root.fresh = false;
                console.warn("[vela] demone: nessun segnale da " + root.staleAfterMs / 1000 + " s, lo rilancio");
                proc.running = false;
            }
        }
    }
}
