// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Dispositivi Bluetooth per il pannello: elenco, scansione, accoppiamento, connessione.
// Il PIN/passkey non passa da qui: BlueZ gestisce l'accoppiamento (dispositivi "Just Works").
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled

    // Dispositivi con nome: collegati, poi accoppiati, poi trovati (per nome). I nomi arrivano da fuori: solo testo semplice.
    readonly property var devices: {
        if (!available) return [];
        var vals = adapter.devices.values, out = [];
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i];
            var name = d.name || d.deviceName;
            if (!name) continue;
            out.push({ ref: d, address: d.address, name: name, connected: d.connected, paired: d.paired || d.bonded,
                       pairing: d.pairing, connecting: d.state === BluetoothDeviceState.Connecting,
                       battery: d.batteryAvailable ? d.battery : -1 });
        }
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    function setEnabled(on) { if (available) adapter.enabled = on; }
    function scan(on) { if (enabled && adapter.discovering !== on) adapter.discovering = on; }
    function stopScan() { if (available && adapter.discovering) adapter.discovering = false; }

    // --- esito ---
    property string error: ""
    property string pendingAddress: ""     // dispositivo di cui abbiamo avviato l'accoppiamento
    Timer { id: errorClear; interval: 10000; onTriggered: root.error = "" }
    Timer { id: pendingClear; interval: 40000; onTriggered: root.pendingAddress = "" }

    function fail(text) { error = text; errorClear.restart(); pendingAddress = ""; }

    Instantiator {
        model: root.available ? root.adapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            // Accoppiato: lo si fida e lo si collega, così le volte dopo si riconnette da solo.
            function onPairedChanged() {
                if (modelData.paired && root.pendingAddress === modelData.address) {
                    root.pendingAddress = "";
                    modelData.trusted = true;
                    modelData.connect();
                }
            }
            function onPairingChanged() {
                if (!modelData.pairing && !modelData.paired && root.pendingAddress === modelData.address)
                    root.fail("Accoppiamento non riuscito (il dispositivo potrebbe richiedere un PIN)");
            }
        }
    }

    // --- azioni (sulla voce di `devices`) ---
    function connect(e) { error = ""; e.ref.connect(); }
    function disconnect(e) { e.ref.disconnect(); }
    function pair(e) {
        error = "";
        pendingAddress = e.address;
        pendingClear.restart();
        e.ref.pair();
    }
    function cancelPair(e) { pendingAddress = ""; e.ref.cancelPair(); }
    function forget(e) { e.ref.forget(); }
}
