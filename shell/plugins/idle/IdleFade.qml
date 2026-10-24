// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Dissolvenza prima del blocco per inattività: lo schermo si oscura piano e, se non si tocca nulla, parte il blocco.
// Un movimento del mouse o un tasto annulla tutto. Non prende né clic né tastiera, così l'attività arriva al compositor.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: fade
        required property var modelData

        screen: modelData
        visible: Idle.fading
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "vela-idle-fade"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            id: veil
            anchors.fill: parent
            color: "black"
            opacity: 0
            NumberAnimation {
                id: dim
                target: veil; property: "opacity"
                from: 0; to: 0.92
                duration: Math.max(1, Idle.fadeSecs * 1000)
            }
        }
        Connections {
            target: Idle
            function onFadingChanged() {
                if (Idle.fading) dim.restart();
                else { dim.stop(); veil.opacity = 0; }
            }
        }
    }
}
