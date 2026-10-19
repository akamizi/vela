// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Profilo energetico: clic = pannello, clic destro o rotellina = passa al successivo.
BarItem {
    tooltip: I18n.tr("Profilo energetico: %1", Power.profileLabel)
    onClicked: button => {
        if (button === Qt.RightButton) Power.cycleProfile();
        else if (button === Qt.LeftButton && MenuModel.availablePanels.indexOf("power") >= 0) Runtime.togglePanel("power", mapToGlobal(width / 2, 0).x);
        else if (button === Qt.LeftButton) Power.cycleProfile();
    }
    onScrolled: Power.cycleProfile()
    BarIcon {
        text: Power.profile === PowerProfile.Performance ? Icons.performance
            : Power.profile === PowerProfile.PowerSaver ? Icons.powerSaver : Icons.balanced
    }
}
