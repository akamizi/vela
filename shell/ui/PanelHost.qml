// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Contenitore dei pannelli: finestra a tutto schermo trasparente (il clic fuori chiude) con una
// scheda accanto alla barra, a destra. Prende la tastiera finché è aperto.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

PanelWindow {
    id: host

    required property string name
    property int contentHeight: 100
    default property alias content: card.data
    readonly property bool open: Runtime.panel === name
    readonly property bool atTop: Config.shell.bar.position === "top"

    screen: Compositor.focusedScreen
    visible: open
    color: "transparent"
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vela-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: Runtime.closePanel() }

    Rectangle {
        id: card
        width: Theme.panelWidth
        height: Math.min(host.contentHeight, host.height - Theme.barHeight - Theme.panelMargin * 3)
        x: host.width - width - Theme.panelMargin
        y: host.atTop ? Theme.barHeight + Theme.panelMargin : host.height - Theme.barHeight - Theme.panelMargin - height
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius
        // I clic dentro la scheda non devono arrivare al livello che chiude il pannello.
        MouseArea { anchors.fill: parent; z: -2 }
    }
}
