// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Stato di rete sintetico (NetworkManager via Quickshell.Networking). I nomi di reti
// arrivano da fuori: vanno mostrati solo come testo semplice.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    // kind: "wifi" | "ethernet" | "none"
    readonly property var summary: {
        var devs = Networking.devices.values;
        var wired = null;
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!d.connected) continue;
            if (d.type === DeviceType.Wifi) {
                var nets = d.networks.values;
                for (var j = 0; j < nets.length; j++)
                    if (nets[j].connected)
                        return { kind: "wifi", name: nets[j].name, signal: nets[j].signalStrength, device: d.name };
            } else if (d.type === DeviceType.Wired && !wired) {
                wired = { kind: "ethernet", name: d.name, signal: 1, device: d.name };
            }
        }
        return wired ? wired : { kind: "none", name: "", signal: 0, device: "" };
    }
}
