// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Giri della ventola; nascosti se il PC non ha un sensore.
BarItem {
    visible: SystemStats.hasFan
    onClicked: SystemMonitor.open()
    BarText { text: Icons.fan; font.family: Theme.iconFamily; color: Theme.muted }
    BarText { text: SystemStats.fanRpm + " RPM" }
}
