// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Barra (Fase 1: vuota, rispetta tema e posizione; mostra gli avvisi di configurazione).
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData

        readonly property bool atTop: Config.shell.bar.position === "top"
        anchors {
            left: true
            right: true
            top: atTop
            bottom: !atTop
        }
        implicitHeight: Theme.barHeight
        color: "transparent"
        WlrLayershell.namespace: "vela-bar"

        Rectangle {
            anchors.fill: parent
            color: Theme.barBackground
            radius: Theme.radius

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.padding
                anchors.verticalCenter: parent.verticalCenter
                text: "vela"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            // Avvisi di configurazione (testo semplice, mai markup).
            Text {
                anchors.right: parent.right
                anchors.rightMargin: Theme.padding
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.warnings.length > 0
                text: "config: " + Config.warnings.join(" · ")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Theme.warning
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
