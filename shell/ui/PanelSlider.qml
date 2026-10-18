// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Cursore orizzontale (D-023): barra sottile con riempimento e maniglia. `value` va da 0 a `maxValue`
// (1 = 100%). Si trascina con il mouse; `moved(v)` dice il nuovo valore, chi lo usa lo applica.
import QtQuick
import "../core"

Item {
    id: root

    property real value: 0
    property real maxValue: 1
    property bool muted: false
    property bool interactive: true
    signal moved(real v)

    readonly property real fraction: Math.max(0, Math.min(1, value / maxValue))
    readonly property bool rounded: Theme.radius > 0

    implicitWidth: 120
    implicitHeight: 20

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 4
        radius: root.rounded ? 2 : 0
        color: Theme.stateSelected
        Rectangle {
            width: track.width * root.fraction
            height: parent.height
            radius: parent.radius
            color: root.muted ? Theme.muted : Theme.accent
        }
    }
    Rectangle {
        visible: root.interactive
        width: 12; height: 12
        radius: root.rounded ? 6 : 0
        x: (root.width - width) * root.fraction
        anchors.verticalCenter: parent.verticalCenter
        color: root.muted ? Theme.muted : Theme.foreground
        border.width: 1
        border.color: Theme.softBorder
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        function pick(m) { root.moved(Math.max(0, Math.min(1, m.x / width)) * root.maxValue); }
        onPressed: m => pick(m)
        onPositionChanged: m => { if (pressed) pick(m); }
    }
}
