// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Profilo energetico: clic = passa al successivo.
BarItem {
    tooltip: "Profilo energetico: " + Power.profileName
    onClicked: button => { if (button === Qt.LeftButton) Power.cycleProfile(); }
    BarIcon {
        text: Power.profile === PowerProfile.Performance ? Icons.performance
            : Power.profile === PowerProfile.PowerSaver ? Icons.powerSaver : Icons.balanced
    }
}
