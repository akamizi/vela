// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Temperatura CPU; nascosta se non c'è un sensore. Rossa oltre la soglia critica.
BarItem {
    id: root
    readonly property bool critical: SystemStats.temperature >= Config.shell.stats.criticalTemperature
    visible: SystemStats.hasTemperature
    onClicked: SystemMonitor.open()
    BarText { text: SystemStats.temperature + "°"; color: root.critical ? Theme.error : Theme.foreground }
    BarText {
        text: Icons.pick(Icons.thermometer, SystemStats.temperature / Config.shell.stats.criticalTemperature)
        font.family: Theme.iconFamily
        color: root.critical ? Theme.error : Theme.muted
    }
}
