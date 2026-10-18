// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Bluetooth: spento / acceso / connesso. Clic destro = accendi/spegni; il pannello arriva in Fase 5.
BarItem {
    visible: BluetoothStatus.available
    tooltip: {
        if (!BluetoothStatus.enabled) return "Bluetooth spento";
        var c = BluetoothStatus.connected;
        if (c.length === 0) return "Bluetooth acceso, nessun dispositivo connesso";
        return c.map(function (d) { return d.name + (d.battery >= 0 ? " " + Math.round(d.battery * 100) + "%" : ""); }).join("\n");
    }
    onClicked: button => { if (button === Qt.RightButton) BluetoothStatus.togglePower(); }
    BarIcon {
        text: !BluetoothStatus.enabled ? Icons.bluetoothOff
            : BluetoothStatus.connected.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
        color: BluetoothStatus.enabled ? Theme.foreground : Theme.muted
    }
}
