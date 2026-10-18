// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Rilevamento dei compositor (D-022): per ciascuno dice se è installato, in esecuzione e attivo
// (quello della sessione), e quali categorie di impostazioni il backend di Vela gestisce.
// L'elenco dei compositor è chiuso: nessun nome arriva dall'esterno nei comandi.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Compositor noti. `backend`: Vela sa pilotarlo (Compositor.qml). `categories`: id -> disponibile.
    readonly property var known: [
        { id: "sway", name: "Sway", binary: "sway", config: "~/.config/sway/config", backend: true,
          categories: { outputs: false, input: false, wallpaper: false, keybindings: false, autostart: false, rules: false, gaps: false } },
        { id: "labwc", name: "labwc", binary: "labwc", config: "~/.config/labwc/rc.xml", backend: false,
          categories: {} }
    ]

    readonly property var categoryLabels: ({
        outputs: "Schermi", input: "Tastiera e touchpad", wallpaper: "Sfondo", keybindings: "Scorciatoie",
        autostart: "Avvio automatico", rules: "Regole delle finestre", gaps: "Bordi e spazi tra le finestre"
    })

    property var installed: ({})
    property var running: ({})

    // Il compositor della sessione, dalle variabili d'ambiente che esporta.
    readonly property string activeId: {
        if (Quickshell.env("SWAYSOCK")) return "sway";
        if (Quickshell.env("LABWC_PID")) return "labwc";
        var d = (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase();
        for (var i = 0; i < known.length; i++) if (d.indexOf(known[i].id) >= 0) return known[i].id;
        return "";
    }

    // [{id, name, installed, running, active, backend, config}]
    readonly property var compositors: known.map(function (c) {
        return { id: c.id, name: c.name, installed: installed[c.id] === true, running: running[c.id] === true,
                 active: c.id === activeId, backend: c.backend, config: c.config };
    })

    readonly property var active: {
        for (var i = 0; i < compositors.length; i++) if (compositors[i].active) return compositors[i];
        return null;
    }
    // Vela sa pilotare il compositor della sessione?
    readonly property bool activeHasBackend: active !== null && active.backend

    // Categorie del compositor attivo: [{id, label, available}]
    readonly property var categories: {
        var out = [];
        for (var i = 0; i < known.length; i++) {
            if (known[i].id !== activeId) continue;
            for (var k in known[i].categories)
                out.push({ id: k, label: categoryLabels[k] || k, available: known[i].categories[k] });
        }
        return out;
    }

    // Cerca i programmi nel PATH e i processi in esecuzione (comando fisso, nessun input esterno).
    Process {
        id: probe
        command: ["sh", "-c", "for c in " + root.known.map(function (c) { return c.binary; }).join(" ")
            + "; do command -v \"$c\" >/dev/null 2>&1 && echo \"inst:$c\"; pgrep -x \"$c\" >/dev/null 2>&1 && echo \"run:$c\"; done; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var inst = {}, run = {};
                text.split("\n").forEach(function (line) {
                    var m = /^(inst|run):([a-z]+)$/.exec(line);
                    if (!m) return;
                    (m[1] === "inst" ? inst : run)[m[2]] = true;
                });
                root.installed = inst;
                root.running = run;
            }
        }
    }

    function refresh() { if (!probe.running) probe.running = true; }
    Component.onCompleted: refresh()
}
