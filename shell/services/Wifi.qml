// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Wi-Fi tramite NetworkManager (Quickshell.Networking). Le credenziali non si salvano né si
// registrano: la password passa direttamente a NetworkManager, che la custodisce.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var wifiDevice: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) if (devs[i].type === DeviceType.Wifi) return devs[i];
        return null;
    }
    readonly property bool available: wifiDevice !== null
    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled

    function setEnabled(on) { Networking.wifiEnabled = on; }

    // La scansione si accende solo mentre il pannello è aperto.
    function scan(on) { if (wifiDevice) wifiDevice.scannerEnabled = on; }

    function isSecured(sec) { return sec !== WifiSecurityType.Open && sec !== WifiSecurityType.Owe && sec !== WifiSecurityType.Unknown; }
    // Reti aziendali (802.1x): servono certificati e profili che il pannello non gestisce.
    function isEnterprise(sec) {
        return sec === WifiSecurityType.Wpa2Eap || sec === WifiSecurityType.WpaEap
            || sec === WifiSecurityType.Wpa3SuiteB192 || sec === WifiSecurityType.Leap
            || sec === WifiSecurityType.DynamicWep;
    }

    // Reti visibili: collegata, poi salvate, poi per segnale. I nomi arrivano da fuori: solo testo semplice.
    readonly property var networks: {
        var dev = wifiDevice;
        if (!dev) return [];
        var vals = dev.networks.values, out = [];
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i];
            if (!n.name) continue;
            out.push({ ref: n, name: n.name, signal: n.signalStrength, security: n.security,
                       secured: isSecured(n.security), enterprise: isEnterprise(n.security),
                       known: n.known, connected: n.connected,
                       connecting: n.state === ConnectionState.Connecting || n.stateChanging });
        }
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signal - a.signal;
        });
        return out;
    }

    // --- esito delle connessioni ---
    property string error: ""
    property string errorNetwork: ""
    property bool needsPassword: false     // l'ultima connessione è fallita per password mancante o errata

    readonly property var reasons: ({
        NoSecrets: "Password mancante o errata",
        WifiAuthTimeout: "Autenticazione scaduta",
        WifiClientFailed: "Connessione non riuscita",
        WifiNetworkLost: "Rete non più raggiungibile",
        WifiClientDisconnected: "Disconnesso dalla rete"
    })

    function onFailed(network, reason) {
        errorNetwork = network.name;
        needsPassword = (reason === ConnectionFailReason.NoSecrets);
        error = reasons[ConnectionFailReason.toString(reason)] || "Connessione non riuscita";
        errorClear.restart();
    }
    function clearError() { error = ""; errorNetwork = ""; needsPassword = false; }
    Timer { id: errorClear; interval: 10000; onTriggered: root.clearError() }

    Instantiator {
        model: root.wifiDevice ? root.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) { root.onFailed(modelData, reason); }
        }
    }

    // --- azioni (sulla voce di `networks`) ---
    function connect(entry) { clearError(); entry.ref.connect(); }
    // La password va solo a NetworkManager; non resta in nessuna proprietà.
    function connectWithPassword(entry, password) { clearError(); entry.ref.connectWithPsk(password); }
    function disconnect(entry) { entry.ref.disconnect(); }
    function forget(entry) { entry.ref.forget(); }

    // --- cavo ---
    readonly property var wired: {
        var out = [], devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wired) out.push({ name: devs[i].name, connected: devs[i].connected, link: devs[i].hasLink, speed: devs[i].linkSpeed });
        return out;
    }
}
