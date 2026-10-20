// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Layout di tastiera (D-037): compare solo se ne sono configurati più di uno. Clic = layout successivo, clic destro = precedente.
BarItem {
    visible: SwayBackend.active && SwayBackend.layoutCount > 1
    tooltip: SwayBackend.layoutName
    onClicked: button => {
        if (button === Qt.LeftButton) SwayBackend.switchLayout(1);
        else if (button === Qt.RightButton) SwayBackend.switchLayout(-1);
    }
    BarIcon { text: Icons.keyboard }
    BarText { text: SwayBackend.layoutCode(SwayBackend.layoutName) }
}
