// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Luce notturna (visibile solo se attiva); clic = disattiva.
BarItem {
    visible: Toggles.night
    tooltip: I18n.tr("Luce notturna attiva")
    onClicked: Toggles.toggleNight()
    BarIcon { text: Icons.night; color: Theme.accent }
}
