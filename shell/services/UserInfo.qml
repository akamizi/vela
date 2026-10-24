// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Dati dell'utente per il pannello utente: nome, nome completo (campo GECOS), computer, tempo di attività e foto (~/.face).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    readonly property string facePath: (Quickshell.env("HOME") || "") + "/.face"
    property string fullName: ""
    property string host: ""
    property real uptimeSecs: 0
    property bool hasFace: false
    readonly property string displayName: fullName !== "" ? fullName : user
    readonly property string initial: displayName !== "" ? displayName.charAt(0).toUpperCase() : "?"

    // "14 ore", "2 giorni 3 ore", "35 minuti"
    readonly property string uptimeText: {
        var m = Math.floor(uptimeSecs / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        if (d > 0) return d === 1 ? I18n.tr("%1 giorno %2 h", d, h % 24) : I18n.tr("%1 giorni %2 h", d, h % 24);
        if (h > 0) return I18n.tr("%1 h %2 min", h, m % 60);
        return I18n.tr("%1 min", m);
    }

    function refresh() { if (!info.running) info.running = true; }

    Process {
        id: info
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; uname -n; cut -d" " -f1 /proc/uptime; [ -r "$HOME/.face" ] && echo 1 || echo 0']
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                root.fullName = (l[0] || "").trim();
                root.host = (l[1] || "").trim();
                root.uptimeSecs = parseFloat(l[2]) || 0;
                root.hasFace = (l[3] || "").trim() === "1";
            }
        }
    }
    Component.onCompleted: refresh()
}
