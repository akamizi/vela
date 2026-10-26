// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// VPN di NetworkManager (vpn e wireguard). Si aggiorna sugli eventi di `nmcli monitor`.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var active: []      // nomi delle VPN attive
    property var known: []       // nomi di tutte le VPN configurate
    readonly property bool available: known.length > 0

    // Formato terso di nmcli: NOME:TIPO, con \: e \ come escape nel nome.
    function parse(text) {
        var names = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var m = /^(.*):([^:]*)$/.exec(lines[i]);
            if (!m) continue;
            if (m[2] !== "vpn" && m[2] !== "wireguard") continue;
            names.push(m[1].replace(/\\(.)/g, "$1"));
        }
        return names;
    }

    Process {
        id: listActive
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector { onStreamFinished: root.active = root.parse(text) }
    }
    Process {
        id: listAll
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector { onStreamFinished: root.known = root.parse(text) }
    }

    function refresh() {
        listActive.running = true;
        listAll.running = true;
    }

    Component.onCompleted: refresh()

    // Eventi di NetworkManager: ogni riga di output fa rileggere lo stato (con debounce).
    // `setpriv --pdeathsig` fa terminare nmcli se Vela muore: senza, a ogni uscita ne resterebbe uno orfano.
    Process {
        running: true
        command: ["sh", "-c", "command -v setpriv >/dev/null && exec setpriv --pdeathsig TERM nmcli monitor; exec nmcli monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
    }
    Timer { id: debounce; interval: 400; onTriggered: root.refresh() }

    // Con una VPN attiva la spegne; altrimenti accende la prima configurata.
    // La scelta tra più VPN arriva con il pannello rete (Fase 4).
    function toggle() {
        if (active.length > 0) {
            for (var i = 0; i < active.length; i++)
                Quickshell.execDetached(["nmcli", "connection", "down", "id", active[i]]);
        } else if (known.length > 0) {
            Quickshell.execDetached(["nmcli", "connection", "up", "id", known[0]]);
        }
    }

    function isActive(name) { return active.indexOf(name) >= 0; }

    // Accende o spegne una VPN precisa (dal pannello rete).
    function toggleOne(name) {
        Quickshell.execDetached(["nmcli", "connection", isActive(name) ? "down" : "up", "id", name]);
    }
}
