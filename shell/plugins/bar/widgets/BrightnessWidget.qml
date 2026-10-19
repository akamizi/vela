// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Luminosità: clic = pannello, rotellina = ±5%. Nascosta se non c'è una retroilluminazione.
BarItem {
    visible: Brightness.available
    tooltip: I18n.tr("Luminosità %1%", Math.round(Brightness.level * 100))
    onClicked: button => {
        if (button === Qt.LeftButton && MenuModel.availablePanels.indexOf("brightness") >= 0) Runtime.togglePanel("brightness", mapToGlobal(width / 2, 0).x);
    }
    onScrolled: direction => Brightness.change(direction * Config.shell.brightness.step)
    BarIcon { text: Icons.pick(Icons.brightness, Brightness.level) }
}
