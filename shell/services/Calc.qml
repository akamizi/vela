// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Calcolatrice del menu (D-031): valuta l'espressione con `qalc` (libqalculate: operazioni, funzioni, unità, valute).
// L'espressione è un solo argomento (preceduta da uno spazio, così non si scambia per un'opzione), mai passata a una shell,
// e il calcolo ha un limite di 2 secondi. La valutazione parte 200 ms dopo l'ultima modifica.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool available: false
    property string expression: ""      // l'ultima richiesta
    property string result: ""          // risultato per `expression` (vuoto finché non arriva)
    property string error: ""
    property bool busy: false

    Process {
        command: ["sh", "-c", "command -v qalc"]
        running: true
        onExited: code => root.available = (code === 0)
    }

    function evaluate(expr) {
        expression = expr.trim();
        result = ""; error = "";
        if (!available || expression === "") { busy = false; debounce.stop(); return; }
        if (expression.length > 200 || /[\u0000-\u001f]/.test(expression)) { busy = false; error = I18n.tr("Espressione non valida"); return; }
        busy = true;
        debounce.restart();
    }

    property string running: ""         // espressione in calcolo
    function start() {
        if (proc.running) { again = true; return; }
        running = expression;
        proc.command = ["timeout", "2", "qalc", "-t", " " + running];
        proc.running = true;
    }
    property bool again: false

    Timer { id: debounce; interval: 200; onTriggered: root.start() }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.running !== root.expression) return;        // risposta di una richiesta superata
                var out = text.trim().split("\n")[0];
                root.busy = false;
                if (out === "") root.error = I18n.tr("Nessun risultato (o calcolo troppo lungo)");
                else root.result = out;
            }
        }
        onExited: {
            if (root.again) { root.again = false; root.start(); }
        }
    }
}
