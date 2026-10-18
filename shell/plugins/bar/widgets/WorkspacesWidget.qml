// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Workspace dello schermo su cui sta la barra; rotellina = precedente/successivo.
BarItem {
    id: root
    clickable: false
    property var screen: QsWindow.window ? QsWindow.window.screen : null
    readonly property var items: screen ? Compositor.workspacesFor(screen, Config.shell.bar.workspaces.persistent) : []

    onScrolled: direction => Compositor.cycle(direction)

    Repeater {
        model: root.items
        delegate: Item {
            id: cell
            required property var modelData
            implicitWidth: label.implicitWidth + Theme.spacing * 2
            implicitHeight: Theme.barHeight

            BarText {
                id: label
                anchors.centerIn: parent
                text: cell.modelData.name
                color: cell.modelData.urgent ? Theme.error
                     : cell.modelData.focused ? Theme.foreground
                     : cell.modelData.present ? Theme.muted : Theme.dim
            }
            Rectangle {
                visible: cell.modelData.focused
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 2
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Compositor.activate(cell.modelData.num)
            }
        }
    }
}
