// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Non disturbare (visibile solo se attivo); clic = disattiva.
BarItem {
    visible: Toggles.dnd
    tooltip: I18n.tr("Non disturbare attivo")
    onClicked: Toggles.toggleDnd()
    BarIcon { text: Icons.dnd; color: Theme.accent }
}
