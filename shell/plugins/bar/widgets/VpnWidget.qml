// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// VPN NetworkManager: nome o "VPN off"; clic = accendi/spegni. Nascosta se non ce ne sono configurate.
BarItem {
    id: root
    readonly property bool on: Vpn.active.length > 0
    visible: Vpn.available
    tooltip: on ? Vpn.active.map(function (n) { return "• " + n; }).join("\n") : "Nessuna VPN attiva"
    onClicked: button => { if (button === Qt.LeftButton) Vpn.toggle(); }
    BarText {
        text: root.on ? (Vpn.active.length === 1 ? "VPN: " + Vpn.active[0] : "VPN: " + Vpn.active.length + " attive") : "VPN off"
        color: root.on ? Theme.foreground : Theme.muted
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Config.shell.bar.vpn.maxWidth)
    }
}
