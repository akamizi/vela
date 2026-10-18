// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Pulsante del menu. Il menu unico arriva in Fase 3: per ora esegue il comando configurato.
BarItem {
    onClicked: button => {
        var c = Config.shell.bar.menuButton.command;
        if (button === Qt.LeftButton && c) Quickshell.execDetached(c);
    }
    BarIcon { text: Icons.menu; font.pixelSize: Theme.iconSize + 2 }
}
