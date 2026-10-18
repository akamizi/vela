// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Rete: Wi-Fi (livello del segnale), cavo o disconnesso. Clic = pannello rete.
BarItem {
    id: root
    readonly property var net: NetworkStatus.summary
    tooltip: net.kind === "wifi" ? net.name + " (" + Math.round(net.signal * 100) + "%)"
           : net.kind === "ethernet" ? net.device : "Disconnesso"
    onClicked: button => { if (button === Qt.LeftButton) Runtime.togglePanel("network"); }
    BarIcon {
        text: root.net.kind === "wifi" ? Icons.pick(Icons.wifi, root.net.signal)
            : root.net.kind === "ethernet" ? Icons.ethernet : Icons.wifiOff
        color: root.net.kind === "none" ? Theme.muted : Theme.foreground
    }
}
