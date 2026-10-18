// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Riga di pannello con gli stati del tema (D-023): normale, sotto il mouse, cursore da tastiera, selezionata.
// Icona a sinistra, titolo, testo a destra e, facoltativo, un controllo (`trailing`).
import QtQuick
import "../core"

Rectangle {
    id: root

    property bool hasCursor: false      // cursore da tastiera
    property bool selected: false       // stato persistente (es. dispositivo corrente)
    property string icon: ""
    property color iconColor: Theme.foreground
    property string title: ""
    property bool bold: false
    property string trailingText: ""
    property color trailingColor: Theme.muted
    property Component trailing: null

    signal clicked()
    signal moved()                      // il mouse si è mosso davvero sopra la riga

    readonly property bool hovered: mouse.containsMouse

    height: Theme.rowHeight
    radius: Theme.radius
    color: selected ? Theme.stateSelected : hasCursor ? Theme.stateCursor : hovered ? Theme.stateHover : "transparent"
    border.width: hasCursor || selected ? 1 : 0
    border.color: hasCursor ? Theme.accent : Theme.softBorder

    BarIcon {
        id: iconItem
        visible: root.icon !== ""
        anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
        text: root.icon
        color: root.iconColor
    }
    BarText {
        anchors {
            left: iconItem.visible ? iconItem.right : parent.left
            leftMargin: iconItem.visible ? Theme.spacing : Theme.padding
            right: rightPart.left; rightMargin: Theme.spacing
            verticalCenter: parent.verticalCenter
        }
        text: root.title
        elide: Text.ElideRight
        font.bold: root.bold
    }
    Row {
        id: rightPart
        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
        spacing: Theme.spacing
        BarText { visible: root.trailingText !== ""; text: root.trailingText; color: root.trailingColor }
        Loader { sourceComponent: root.trailing; anchors.verticalCenter: parent.verticalCenter }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property point last: Qt.point(-1, -1)
        onClicked: root.clicked()
        // Un movimento sintetico (la scheda compare sotto un puntatore fermo) non sposta il cursore da tastiera.
        onPositionChanged: m => {
            var g = mapToGlobal(m.x, m.y);
            if (g.x === last.x && g.y === last.y) return;
            last = g;
            root.moved();
        }
    }
}
