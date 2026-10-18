// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Bottone di azione piccolo, con bordo sottile (D-023).
import QtQuick
import "../core"

Rectangle {
    id: root

    property string text: ""
    property bool danger: false
    signal clicked()

    readonly property bool hot: mouse.containsMouse
    implicitWidth: label.implicitWidth + Theme.padding * 2
    implicitHeight: Theme.rowHeight - 10
    radius: Theme.radius
    color: hot ? Theme.stateHover : "transparent"
    border.width: 1
    border.color: hot ? (danger ? Theme.error : Theme.accent) : Theme.softBorder

    BarText {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.danger && root.hot ? Theme.error : Theme.foreground
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
