// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../core"
import "../../../services"
import "../../../ui"
// Finestre iconificate (visibile solo se ce n'è almeno una): un'icona ciascuna, clic = ripristina e porta in primo piano.
// Serve soprattutto in labwc, che le nasconde senza altro modo di richiamarle; in Sway non compare mai.
BarItem {
    id: root

    clickable: false
    readonly property var hidden: (ToplevelManager.toplevels.values || []).filter(function (t) { return t.minimized; })
    visible: hidden.length > 0

    Repeater {
        model: root.hidden
        delegate: Item {
            id: cell
            required property var modelData
            readonly property string icon: {
                var id = modelData.appId || "";
                var e = id !== "" ? DesktopEntries.heuristicLookup(id) : null;
                return Apps.iconSource(e && e.icon ? e.icon : id.toLowerCase());
            }
            width: Theme.barIconSize + 4
            height: Theme.barHeight

            Image {
                anchors.centerIn: parent
                width: Theme.barIconSize; height: Theme.barIconSize
                source: cell.icon
                visible: cell.icon !== ""
                sourceSize: Qt.size(Theme.barIconSize * 2, Theme.barIconSize * 2)
                smooth: true
            }
            BarText {
                anchors.centerIn: parent
                visible: cell.icon === ""
                text: (cell.modelData.appId || cell.modelData.title || "?").charAt(0).toUpperCase()
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.tooltip = cell.modelData.title || cell.modelData.appId || ""
                onExited: root.tooltip = ""
                onClicked: {
                    cell.modelData.minimized = false;
                    cell.modelData.activate();
                }
            }
        }
    }
}
