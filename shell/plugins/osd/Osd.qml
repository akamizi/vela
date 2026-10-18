// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// OSD di volume e luminosità (D-012): compare a ogni cambio, da qualunque origine, poi si nasconde.
// Non prende né clic né tastiera.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelWindow {
    id: osd

    property string kind: "volume"      // "volume" | "brightness"
    property real value: 0
    property bool muted: false
    property bool shown: false
    property bool armed: false          // dopo l'avvio e a ogni cambio di uscita si ignora il primo valore

    readonly property bool atTop: Config.shell.bar.position === "top"

    screen: Compositor.focusedScreen
    visible: shown
    color: "transparent"
    anchors { bottom: !atTop; top: atTop }
    margins { bottom: Theme.barHeight + Theme.panelMargin * 3; top: Theme.barHeight + Theme.panelMargin * 3 }
    implicitWidth: card.width
    implicitHeight: card.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vela-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}                      // finestra trasparente agli eventi

    function show(k, v, m) {
        if (!armed) return;
        kind = k; value = v; muted = m;
        shown = true;
        hide.restart();
    }

    Timer { id: hide; interval: Config.shell.osd.timeout; onTriggered: osd.shown = false }
    Timer { id: arm; interval: 1500; running: true; onTriggered: osd.armed = true }

    Connections {
        target: Audio
        function onVolumeChanged() { osd.show("volume", Audio.volume, Audio.muted); }
        function onMutedChanged() { osd.show("volume", Audio.volume, Audio.muted); }
        // Cambiare uscita cambia anche il volume letto: non è un'azione dell'utente sul volume.
        function onSinkChanged() { osd.armed = false; arm.restart(); }
    }
    Connections {
        target: Brightness
        function onLevelChanged() { osd.show("brightness", Brightness.level, false); }
    }

    Rectangle {
        id: card
        width: 300
        height: Theme.rowHeight + Theme.padding
        color: Theme.surface
        border.color: Theme.softBorder
        border.width: 1
        radius: Theme.radius

        Row {
            anchors { fill: parent; leftMargin: Theme.padding; rightMargin: Theme.padding }
            spacing: Theme.padding
            BarIcon {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                text: osd.kind === "brightness" ? Icons.pick(Icons.brightness, osd.value)
                    : osd.muted ? Icons.volumeMuted : Icons.pick(Icons.volume, osd.value)
                color: osd.muted ? Theme.muted : Theme.accent
            }
            PanelSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - icon.width - pct.width - parent.spacing * 2
                value: osd.value
                maxValue: 1
                muted: osd.muted
                interactive: false
            }
            BarText {
                id: pct
                width: 40
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round(osd.value * 100) + "%"
                color: Theme.muted
            }
        }
    }
}
