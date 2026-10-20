// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Meteo: icona e temperatura; tooltip con le previsioni. Clic = pannello, clic destro o centrale = aggiorna.
BarItem {
    visible: Weather.enabled && Weather.text !== ""
    tooltip: Weather.tooltip
    onClicked: button => {
        if (button === Qt.RightButton || button === Qt.MiddleButton) Weather.refresh();
        else if (button === Qt.LeftButton && MenuModel.availablePanels.indexOf("weather") >= 0) Runtime.togglePanel("weather", mapToGlobal(width / 2, 0).x);
    }
    BarText { text: Weather.text; font.family: Theme.iconFamily }
}
