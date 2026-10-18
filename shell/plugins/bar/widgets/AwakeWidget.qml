// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// "Resta sveglio": inibitore di idle Wayland legato alla finestra della barra.
// Visibile solo se attivo; clic = disattiva. L'attivazione sta nel menu (Fase 3).
BarItem {
    id: root
    visible: Toggles.awake
    tooltip: "Resta sveglio: blocco schermo disattivato"
    onClicked: Toggles.setAwake(false)

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: Toggles.awake
    }
    BarIcon { text: Icons.awake; color: Theme.accent }
}
