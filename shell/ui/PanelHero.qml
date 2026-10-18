// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Intestazione grande di un pannello (D-023): icona, titolo, riga in maiuscolo piccolo, pillola di
// dettaglio e un controllo a destra (es. ToggleSwitch).
import QtQuick
import "../core"

Item {
    id: root

    property string icon: ""
    property color iconColor: Theme.foreground
    property string title: ""
    property string meta: ""
    property string detail: ""
    property Component trailing: null

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(labels.implicitHeight, iconItem.implicitHeight, trailingLoader.implicitHeight) + Theme.padding * 2

    BarIcon {
        id: iconItem
        anchors { left: parent.left; leftMargin: Theme.padding + 2; verticalCenter: parent.verticalCenter }
        text: root.icon
        color: root.iconColor
        font.pixelSize: Theme.iconSize * 2
    }

    Column {
        id: labels
        anchors {
            left: iconItem.right; leftMargin: Theme.padding
            right: trailingLoader.left; rightMargin: Theme.padding
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Row {
            width: parent.width
            spacing: Theme.spacing
            BarText {
                id: titleText
                text: root.title
                font.bold: true
                font.pixelSize: Theme.fontSize + 3
                width: Math.min(implicitWidth, Math.max(0, parent.width - (pill.visible ? pill.width + Theme.spacing : 0)))
                elide: Text.ElideRight
            }
            Rectangle {
                id: pill
                visible: root.detail !== ""
                width: pillText.implicitWidth + Theme.spacing * 2
                height: pillText.implicitHeight + 4
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radius > 0 ? height / 2 : 0
                color: "transparent"
                border.width: 1
                border.color: Theme.softBorder
                BarText {
                    id: pillText
                    anchors.centerIn: parent
                    text: root.detail
                    color: Theme.muted
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: true
                }
            }
        }
        BarText {
            visible: text !== ""
            width: parent.width
            text: root.meta.toUpperCase()
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
            font.bold: true
            font.letterSpacing: 1.2
            elide: Text.ElideRight
        }
    }

    Loader {
        id: trailingLoader
        sourceComponent: root.trailing
        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
    }
}
