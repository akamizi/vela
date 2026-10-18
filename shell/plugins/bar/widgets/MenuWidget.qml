// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Pulsante del menu: clic = apre il menu completo.
BarItem {
    onClicked: button => { if (button === Qt.LeftButton) Runtime.toggleMenu("menu"); }
    BarIcon { text: Icons.menu; font.pixelSize: Theme.barIconSize + 2 }
}
