// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Interruttore a scorrimento senza etichetta (D-023). Chi lo usa lega `checked` allo stato reale
// e lo cambia in risposta a `toggled()`. `busy` ignora i clic mentre un'operazione è in corso.
// Segue il tema: forma a pillola se gli angoli sono arrotondati, squadrata altrimenti.
import QtQuick
import "../core"

Item {
    id: root

    property bool checked: false
    property bool busy: false
    property bool hasCursor: false       // cursore da tastiera del pannello
    property bool interactive: true
    signal toggled()

    readonly property bool rounded: Theme.radius > 0
    readonly property bool hot: hasCursor || mouse.containsMouse
    readonly property int trackHeight: 22
    readonly property int trackWidth: 42
    readonly property int knobSize: 16
    readonly property int pad: 3        // spazio per l'anello del cursore

    implicitWidth: trackWidth + pad * 2
    implicitHeight: trackHeight + pad * 2

    // anello attorno al controllo quando ha il cursore o il mouse
    Rectangle {
        anchors.fill: parent
        visible: root.hot && root.interactive
        color: "transparent"
        radius: root.rounded ? height / 2 : 0
        border.width: 1
        border.color: Theme.accent
    }

    Rectangle {
        id: track
        width: root.trackWidth
        height: root.trackHeight
        anchors.centerIn: parent
        radius: root.rounded ? height / 2 : 0
        color: root.checked ? Theme.accent : Theme.stateSelected
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.softBorder
        opacity: root.busy ? 0.6 : 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: root.knobSize
            height: root.knobSize
            radius: root.rounded ? height / 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - 3 : 3
            color: root.checked ? Theme.background : Theme.muted
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!root.busy) root.toggled()
    }
}
