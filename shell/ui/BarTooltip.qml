// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Tooltip sotto (barra in alto) o sopra (barra in basso) l'elemento di riferimento.
import QtQuick
import Quickshell
import "../core"

PopupWindow {
    id: root
    required property Item target
    property string text: ""
    property bool mono: false
    property bool shown: false

    readonly property bool atTop: Config.shell.bar.position === "top"

    visible: shown && text !== ""
    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    anchor.item: target
    anchor.edges: atTop ? Edges.Bottom : Edges.Top
    anchor.gravity: atTop ? Edges.Bottom : Edges.Top
    anchor.adjustment: PopupAdjustment.Slide

    Rectangle {
        id: card
        implicitWidth: label.implicitWidth + Theme.padding * 2
        implicitHeight: label.implicitHeight + Theme.padding
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            textFormat: Text.PlainText
            color: Theme.foreground
            font.family: root.mono ? Theme.monoFamily : Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
