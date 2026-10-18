// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Meteo: icona e temperatura; tooltip con le previsioni. Clic destro = aggiorna.
BarItem {
    visible: Weather.enabled && Weather.text !== ""
    tooltip: Weather.tooltip
    onClicked: button => { if (button === Qt.RightButton) Weather.refresh(); }
    BarText { text: Weather.text; font.family: Theme.iconFamily }
}
