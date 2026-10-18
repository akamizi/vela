// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Stato Bluetooth sintetico (BlueZ via Quickshell.Bluetooth).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    // [{name, battery (0..1 o -1)}]
    readonly property var connected: {
        var out = [];
        if (!available) return out;
        var devs = adapter.devices.values;
        for (var i = 0; i < devs.length; i++)
            if (devs[i].connected)
                out.push({ name: devs[i].name || devs[i].deviceName, battery: devs[i].batteryAvailable ? devs[i].battery : -1 });
        return out;
    }

    function togglePower() {
        if (available) adapter.enabled = !adapter.enabled;
    }
}
