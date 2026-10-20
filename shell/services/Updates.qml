// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Aggiornamenti disponibili (D-037): interroga il gestore dei pacchetti (di default `xbps-install -un`, senza root) a intervalli
// e conta i pacchetti da aggiornare. Il controllo legge l'indice locale: si aggiorna quando qualcuno lo sincronizza
// (`xbps-install -S` o un aggiornamento completo), non scarica niente da sé. Il comando di aggiornamento si lancia in un terminale.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    readonly property var cfg: Config.shell.updates
    readonly property bool enabled: cfg.enabled === true && Array.isArray(cfg.checkCommand) && cfg.checkCommand.length > 0
    property int count: 0
    property var names: []
    property bool running: false          // l'aggiornamento è in corso nel terminale

    function validCommand(c) { return Array.isArray(c) && c.length > 0 && c.every(function (x) { return typeof x === "string"; }); }

    // Una riga per pacchetto: "nome-versione update arch repo dimensioni". Si contano solo gli aggiornamenti (non le installazioni di dipendenze).
    function parse(text) {
        var out = [];
        text.split("\n").forEach(function (l) {
            var f = l.trim().split(/\s+/);
            if (f.length >= 2 && f[1] === "update") out.push(f[0]);
        });
        names = out;
        count = out.length;
    }

    function refresh() { if (enabled && !check.running) check.running = true; }

    Process {
        id: check
        command: root.validCommand(root.cfg.checkCommand) ? root.cfg.checkCommand : ["true"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    // Avvia l'aggiornamento in un terminale (comando dalla configurazione); a fine lavoro si ricontrolla.
    function upgrade() {
        if (running || !validCommand(cfg.command)) return;
        running = true;
        upgrader.command = cfg.command;
        upgrader.running = true;
    }
    Process {
        id: upgrader
        onExited: { root.running = false; root.refresh(); }
    }

    // Primo controllo qualche secondo dopo l'avvio, per non pesare sull'avvio della sessione.
    Timer { interval: 20000; running: root.enabled; onTriggered: root.refresh() }
    Timer { interval: Math.max(60, Number(root.cfg.interval) || 3600) * 1000; running: root.enabled; repeat: true; onTriggered: root.refresh() }
}
