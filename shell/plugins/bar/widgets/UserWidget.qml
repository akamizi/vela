// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell.Widgets
import "../../../core"
import "../../../services"
import "../../../ui"
// Utente: la foto (~/.face) o l'iniziale in un cerchio. Il clic apre il pannello utente.
BarItem {
    id: root
    readonly property int size: Theme.barIconSize + 6
    tooltip: UserInfo.displayName
    onClicked: button => {
        if (button === Qt.LeftButton) Runtime.togglePanel("user", mapToGlobal(width / 2, 0).x);
    }
    ClippingRectangle {
        width: root.size; height: root.size
        radius: width / 2
        color: Theme.stateSelected
        border.width: 1
        border.color: root.hovered ? Theme.accent : Theme.softBorder
        Image {
            anchors.fill: parent
            visible: UserInfo.hasFace && status === Image.Ready
            source: UserInfo.hasFace ? "file://" + UserInfo.facePath : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            asynchronous: true
        }
        BarText {
            anchors.centerIn: parent
            visible: !UserInfo.hasFace
            text: UserInfo.initial
            font.bold: true
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
