// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Barra: tre zone (sinistra, centro, destra) riempite dagli elementi elencati in configurazione.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

Variants {
    // bar.screen: nome dell'uscita (es. "eDP-1") che ha la barra; vuoto, o nome assente (schermo scollegato), = tutti gli schermi.
    readonly property string only: Config.shell.bar.screen || ""
    model: {
        var all = Quickshell.screens;
        if (only === "") return all;
        var one = all.filter(function (s) { return s.name === only; });
        return one.length > 0 ? one : all;
    }

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

        // Il mouse è sulla barra: gli indicatori (elemento Indicators) mostrano anche quelli spenti.
        readonly property bool pointerInside: barHover.hovered

        // Un elemento è un file widgets/<Nome>Widget.qml; il nome viene dalla configurazione,
        // quindi si accetta solo la forma Maiuscola+lettere (niente percorsi).
        // Gli elementi consecutivi dello stesso gruppo (bar.groups) stanno vicini; tra gruppi diversi c'è
        // bar.groupGap. Un gruppo senza elementi visibili sparisce con il suo spazio.
        component Zone: Row {
            id: zone
            property var names: []
            readonly property var runs: {
                var groups = Config.shell.bar.groups || {};
                var out = [], last = null;
                for (var i = 0; i < names.length; i++) {
                    var g = groups[names[i]] || "";
                    if (out.length === 0 || g !== last) out.push([]);
                    out[out.length - 1].push(names[i]);
                    last = g;
                }
                return out;
            }
            readonly property int gap: Config.shell.bar.groupGap !== undefined ? Config.shell.bar.groupGap : Theme.spacing * 2
            // larghezza di ogni gruppo: lo spazio si mette solo tra gruppi con qualcosa di visibile
            property var widths: ({})
            function anyBefore(index) {
                for (var i = 0; i < index; i++) if ((widths[i] || 0) > 0) return true;
                return false;
            }

            Repeater {
                model: zone.runs
                delegate: Item {
                    id: run
                    required property var modelData
                    required property int index
                    readonly property real inner: items.implicitWidth
                    readonly property real lead: inner > 0 && zone.anyBefore(index) ? zone.gap : 0
                    onInnerChanged: { var w = zone.widths; w[index] = inner; zone.widths = w; }
                    width: lead + inner
                    height: Theme.barHeight
                    Row {
                        id: items
                        x: run.lead
                        Repeater {
                            model: run.modelData
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
                    }
                }
            }
        }

        Rectangle {
            id: barBody
            readonly property bool isBarZone: true
            // Dissolvenza in entrata all'avvio della barra (bar.fadeIn, ms); 0 = comparsa immediata
            readonly property int fadeMs: Math.max(0, Number(Config.shell.bar.fadeIn) || 0)
            Component.onCompleted: if (fadeMs > 0) { opacity = 0; barFade.start(); }
            NumberAnimation { id: barFade; target: barBody; property: "opacity"; from: 0; to: 1; duration: barBody.fadeMs; easing.type: Easing.OutCubic }
            anchors.fill: parent
            color: Theme.barBackground
            radius: Theme.barRadius

            HoverHandler { id: barHover }

            Row {
                id: left
                anchors { left: parent.left; leftMargin: Theme.spacing; top: parent.top; bottom: parent.bottom }
                Zone { names: Config.shell.bar.modules.left }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
                Zone { names: Config.shell.bar.modules.center }
            }
            Row {
                anchors { right: parent.right; rightMargin: Theme.spacing; top: parent.top; bottom: parent.bottom }
                Zone { names: Config.shell.bar.modules.right }
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
