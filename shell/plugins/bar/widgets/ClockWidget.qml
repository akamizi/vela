// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Orologio: clic = calendario, clic destro = formato alternativo; tooltip = data per esteso.
BarItem {
    id: root
    property bool alt: false
    readonly property var loc: Config.shell.bar.clock.locale ? Qt.locale(Config.shell.bar.clock.locale) : Qt.locale()
    readonly property var cfg: Config.shell.bar.clock

    tooltip: clock.date.toLocaleDateString(loc, "dddd d MMMM yyyy")
    onClicked: button => {
        if (button === Qt.RightButton) alt = !alt;
        else if (button === Qt.LeftButton && MenuModel.availablePanels.indexOf("calendar") >= 0) Runtime.togglePanel("calendar", mapToGlobal(width / 2, 0).x);
        else if (button === Qt.LeftButton) alt = !alt;
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    BarText {
        text: clock.date.toLocaleString(root.loc, root.alt ? root.cfg.formatAlt : root.cfg.format)
    }
}
