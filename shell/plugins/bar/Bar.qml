// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Barra: tre zone (sinistra, centro, destra) riempite dagli elementi elencati in configurazione.
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
        visible: Runtime.barVisible
        WlrLayershell.namespace: "vela-bar"

        // Un elemento è un file widgets/<Nome>Widget.qml; il nome viene dalla configurazione,
        // quindi si accetta solo la forma Maiuscola+lettere (niente percorsi).
        component Zone: Repeater {
            delegate: Loader {
                required property string modelData
                readonly property bool valid: /^[A-Z][A-Za-z]*$/.test(modelData)
                source: valid ? "widgets/" + modelData + "Widget.qml" : ""
                // Un elemento nascosto (es. batteria assente) non occupa spazio. Il Loader resta
                // visibile: se dipendesse da item.visible, che include quello del genitore, si bloccherebbe.
                width: item && item.visible ? item.implicitWidth : 0
                height: Theme.barHeight
                onStatusChanged: {
                    if (status === Loader.Error || !valid)
                        console.warn("[vela] elemento di barra sconosciuto o non caricabile: " + modelData);
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.barBackground
            radius: Theme.radius

            Row {
                id: left
                anchors { left: parent.left; leftMargin: Theme.spacing; top: parent.top; bottom: parent.bottom }
                Zone { model: Config.shell.bar.modules.left }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
                Zone { model: Config.shell.bar.modules.center }
            }
            Row {
                anchors { right: parent.right; rightMargin: Theme.spacing; top: parent.top; bottom: parent.bottom }
                Zone { model: Config.shell.bar.modules.right }
            }

            // Avvisi di configurazione (testo semplice, mai markup), sopra tutto il resto.
            Rectangle {
                visible: Config.warnings.length > 0
                anchors.centerIn: parent
                color: Theme.surface
                border.color: Theme.warning
                width: warn.implicitWidth + Theme.padding * 2
                height: parent.height
                Text {
                    id: warn
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, bar.width * 0.6)
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
}
