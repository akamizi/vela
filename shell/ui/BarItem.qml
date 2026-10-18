// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Elemento base della barra: contenuto, clic, rotellina e tooltip al passaggio del mouse.
import QtQuick
import "../core"

Item {
    id: root

    property string tooltip: ""
    property bool tooltipMono: false
    property bool clickable: true

    signal clicked(int button)
    signal scrolled(int direction)   // +1 su, -1 giù

    default property alias content: row.data
    readonly property alias hovered: mouse.containsMouse

    implicitWidth: row.implicitWidth + Theme.spacing * 2
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        z: -1   // sotto il contenuto: i figli con un proprio MouseArea (workspace, tray) ricevono i clic
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: {
            if (containsMouse) delay.restart();
            else { delay.stop(); root.tipShown = false; }
        }
        onClicked: mouse => root.clicked(mouse.button)
        onWheel: wheel => {
            if (wheel.angleDelta.y !== 0) root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }

    // Il tooltip compare dopo una breve attesa, per non lampeggiare passando sopra la barra.
    property bool tipShown: false
    Timer {
        id: delay
        interval: 350
        onTriggered: root.tipShown = true
    }

    // Il tooltip si crea solo quando serve: ogni PopupWindow ha un costo.
    Loader {
        active: root.tipShown && root.tooltip !== ""
        sourceComponent: BarTooltip {
            target: root
            text: root.tooltip
            mono: root.tooltipMono
            shown: true
        }
    }
}
