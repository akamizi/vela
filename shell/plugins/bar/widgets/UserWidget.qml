// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Utente: icona dell'omino. Il clic apre il pannello utente (con la foto).
BarItem {
    tooltip: UserInfo.displayName
    onClicked: button => {
        if (button === Qt.LeftButton) Runtime.togglePanel("user", mapToGlobal(width / 2, 0).x);
    }
    BarIcon { text: Icons.account }
}
