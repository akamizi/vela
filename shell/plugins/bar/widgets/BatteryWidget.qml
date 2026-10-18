// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Batteria: percentuale e icona, colori di avviso e critico. Nascosta senza batteria.
BarItem {
    id: root
    readonly property real pct: Power.percent
    readonly property bool low: pct <= Config.shell.battery.warning && !Power.charging
    readonly property bool critical: pct <= Config.shell.battery.critical && !Power.charging
    visible: Power.hasBattery
    tooltip: {
        var s = Math.round(Power.percent) + "%";
        if (Power.charging) s += " · in carica";
        else if (Power.plugged) s += " · collegata";
        var t = Power.secondsLeft;
        if (t > 0 && !Power.plugged) {
            var h = Math.floor(t / 3600), m = Math.round((t % 3600) / 60);
            s += " · " + (h > 0 ? h + " h " : "") + m + " min";
        }
        return s;
    }
    BarText {
        text: Math.round(root.pct) + "%"
        color: root.critical ? Theme.error : root.low ? Theme.warning : Theme.foreground
    }
    BarIcon {
        text: Power.plugged ? Icons.plug : Icons.pick(Power.charging ? Icons.batteryCharging : Icons.battery, root.pct / 100)
        color: root.critical ? Theme.error : root.low ? Theme.warning : Theme.foreground
    }
}
