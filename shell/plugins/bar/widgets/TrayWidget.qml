// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Tray a cassetto: la freccia apre/chiude. Clic sinistro = attiva, destro = menu.
import Quickshell.Services.SystemTray

BarItem {
    id: root
    property bool expanded: !Config.shell.tray.collapsed
    visible: Config.shell.tray.enabled && SystemTray.items.values.length > 0
    clickable: false

    BarItem {
        implicitWidth: arrow.implicitWidth + Theme.spacing
        onClicked: root.expanded = !root.expanded
        BarIcon { id: arrow; text: root.expanded ? Icons.trayExpanded : Icons.trayCollapsed }
    }

    Repeater {
        model: Config.shell.tray.enabled ? SystemTray.items : []
        delegate: Item {
            id: cell
            required property var modelData
            visible: root.expanded
            width: visible ? Theme.barIconSize + 4 : 0
            height: Theme.barHeight

            Image {
                anchors.centerIn: parent
                width: Theme.barIconSize; height: Theme.barIconSize
                source: cell.modelData.icon
                sourceSize: Qt.size(Theme.barIconSize * 2, Theme.barIconSize * 2)
                smooth: true
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    var p = cell.mapToItem(null, 0, 0);
                    if (mouse.button === Qt.LeftButton && !cell.modelData.onlyMenu) cell.modelData.activate();
                    else if (mouse.button === Qt.MiddleButton) cell.modelData.secondaryActivate();
                    else if (cell.modelData.hasMenu) cell.modelData.display(cell.QsWindow.window, p.x, p.y + cell.height);
                }
            }
        }
    }
}
