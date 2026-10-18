// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Luminosità dello schermo: lettura da sysfs, modifica con brightnessctl.
// sysfs non emette eventi per questo file: si rilegge a intervalli lunghi.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool available: false
    property real level: 0           // 0..1
    property string device: ""
    property real maxValue: 1

    Process {
        id: probe
        command: ["brightnessctl", "-m", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // formato: dispositivo,classe,valore,percentuale,massimo
                var f = text.trim().split(",");
                if (f.length >= 5 && f[1] === "backlight") {
                    root.device = f[0];
                    root.maxValue = Number(f[4]);
                    root.available = root.maxValue > 0;
                    root.read();
                }
            }
        }
    }

    FileView {
        id: current
        path: root.available ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        blockLoading: true
        printErrors: false
    }

    function read() {
        if (!available) return;
        current.reload();
        var v = Number(current.text().trim());
        if (!isNaN(v)) level = Math.max(0, Math.min(1, v / maxValue));
    }

    Timer {
        interval: Config.shell.osd.enabled ? 1000 : 3000    // con l'OSD serve una risposta pronta ai tasti
        running: root.available
        repeat: true
        onTriggered: root.read()
    }

    Process {
        id: setter
        onExited: root.read()
    }

    // step in percentuale (positivo o negativo)
    function change(stepPercent) {
        if (!available || setter.running) return;
        setter.command = ["brightnessctl", "set", Math.abs(stepPercent) + "%" + (stepPercent > 0 ? "+" : "-")];
        setter.running = true;
    }
}
