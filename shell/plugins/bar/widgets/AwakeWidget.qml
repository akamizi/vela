// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// "Resta sveglio": indicatore ben visibile (pillola colorata) mentre è attivo; clic = disattiva.
// Attivo se lo è l'inibitore interno di Vela (inibitore di idle Wayland legato alla finestra della barra)
// oppure quello esterno configurato in toggles.awakeCommand.
BarItem {
    id: root
    visible: Toggles.awakeOn
    tooltip: "Resta sveglio: il blocco dello schermo è sospeso. Clic per disattivare."
    onClicked: Toggles.stopAwake()

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: Toggles.awake
    }

    Rectangle {
        width: inner.implicitWidth + Theme.spacing * 2
        height: Theme.barHeight - 8
        radius: Math.min(height / 2, Math.max(3, Theme.barRadius))
        color: Theme.warning
        Row {
            id: inner
            anchors.centerIn: parent
            spacing: Theme.gap
            BarIcon { text: Icons.awake; color: Theme.background; anchors.verticalCenter: parent.verticalCenter }
            BarText { text: "SVEGLIO"; font.bold: true; color: Theme.background; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
