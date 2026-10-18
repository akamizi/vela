// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Intestazione di una sezione di pannello: testo piccolo in maiuscolo, spaziato e attenuato (D-023).
import QtQuick
import "../core"

Item {
    id: root

    property string text: ""
    readonly property int fontPx: Theme.fontSize - 2

    width: parent ? parent.width : implicitWidth
    implicitHeight: 28

    BarText {
        anchors { left: parent.left; leftMargin: Theme.padding; right: parent.right; rightMargin: Theme.padding; bottom: parent.bottom; bottomMargin: 3 }
        text: root.text.toUpperCase()
        color: Theme.dim
        font.pixelSize: root.fontPx
        font.bold: true
        font.letterSpacing: 1.2
        elide: Text.ElideRight
        // I glifi possono sporgere sopra il riquadro del testo e una lista che taglia li mozzerebbe
        topPadding: Math.ceil(root.fontPx * 0.15)
    }
}
