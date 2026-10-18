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
    property int cardWidth: Theme.panelWidth
    // centered: finestra rettangolare al centro dello schermo (impostazioni), con sfondo attenuato
    property bool centered: false
    property int cardHeight: 0
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

    Rectangle {
        anchors.fill: parent
        visible: host.centered
        color: Qt.alpha(Theme.background, 0.55)
    }
    MouseArea { anchors.fill: parent; onClicked: Runtime.closePanel() }

    Rectangle {
        id: card
        width: host.cardWidth
        height: host.centered ? Math.min(host.cardHeight, host.height - Theme.barHeight * 2 - Theme.panelMargin * 2)
                              : Math.min(host.contentHeight, host.height - Theme.barHeight - Theme.panelMargin * 3)
        x: host.centered ? (host.width - width) / 2
         : Runtime.panelAnchorX >= 0 ? Math.max(Theme.panelMargin, Math.min(host.width - width - Theme.panelMargin, Runtime.panelAnchorX - width / 2))
         : host.width - width - Theme.panelMargin
        y: host.centered ? (host.height - height) / 2
                         : host.atTop ? Theme.barHeight + Theme.panelMargin : host.height - Theme.barHeight - Theme.panelMargin - height
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius
        // I clic dentro la scheda non devono arrivare al livello che chiude il pannello.
        MouseArea { anchors.fill: parent; z: -2 }
    }
}
