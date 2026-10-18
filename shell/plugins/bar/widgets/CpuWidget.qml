// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Uso CPU; clic = monitor di sistema (se configurato).
BarItem {
    onClicked: SystemMonitor.open()
    BarText { text: Icons.cpu; font.family: Theme.iconFamily; color: Theme.muted }
    BarText { text: SystemStats.cpu + "%" }
}
