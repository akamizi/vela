// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Applicazioni predefinite (D-024, 3b): per ogni gruppo di tipi di file elenca le applicazioni che lo gestiscono,
// legge quella predefinita (`xdg-mime query default`) e la cambia (`xdg-mime default`, `xdg-settings`).
// I tipi di file sono un elenco chiuso e gli identificativi .desktop si validano: nessuna stringa libera nei comandi.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // `mimes[0]` serve per cercare i candidati e per leggere il valore attuale; tutti vengono impostati.
    readonly property var groups: [
        { id: "web", label: "Browser web", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] },
        { id: "files", label: "Gestore di file", mimes: ["inode/directory"] },
        { id: "text", label: "Editor di testo", mimes: ["text/plain"] },
        { id: "pdf", label: "Lettore PDF", mimes: ["application/pdf"] },
        { id: "image", label: "Visualizzatore di immagini", mimes: ["image/png", "image/jpeg", "image/gif", "image/webp"] },
        { id: "video", label: "Lettore video", mimes: ["video/mp4", "video/x-matroska", "video/webm"] },
        { id: "audio", label: "Lettore audio", mimes: ["audio/mpeg", "audio/flac", "audio/ogg"] },
        { id: "mail", label: "Client di posta", mimes: ["x-scheme-handler/mailto"] }
    ]

    property var candidates: ({})     // gruppo -> [{id, name}]
    property var current: ({})        // gruppo -> id .desktop
    property bool busy: false

    function validId(id) { return typeof id === "string" && /^[A-Za-z0-9._\-]+\.desktop$/.test(id); }

    function nameOf(id) {
        var e = DesktopEntries.byId(id) || DesktopEntries.byId(id.replace(/\.desktop$/, ""));
        return e ? e.name : id.replace(/\.desktop$/, "");
    }

    // Una riga per file .desktop con tipi di file: "<id>\t<tipi separati da ;>". Comando fisso, nessun input esterno.
    Process {
        id: scan
        command: ["sh", "-c",
            'for d in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" /usr/local/share/applications /usr/share/applications; do ' +
            '[ -d "$d" ] || continue; for f in "$d"/*.desktop; do [ -f "$f" ] || continue; ' +
            'grep -q "^NoDisplay=true" "$f" && continue; ' +
            'm=$(sed -n "s/^MimeType=//p" "$f" | head -n1); [ -n "$m" ] && printf "%s\\t%s\\n" "${f##*/}" "$m"; done; done']
        stdout: StdioCollector {
            onStreamFinished: {
                var byGroup = {};
                root.groups.forEach(function (g) { byGroup[g.id] = {}; });
                text.split("\n").forEach(function (line) {
                    var p = line.split("\t");
                    if (p.length < 2 || !root.validId(p[0])) return;
                    var types = p[1].split(";");
                    root.groups.forEach(function (g) {
                        if (types.indexOf(g.mimes[0]) >= 0) byGroup[g.id][p[0]] = true;
                    });
                });
                var out = {};
                root.groups.forEach(function (g) {
                    out[g.id] = Object.keys(byGroup[g.id]).map(function (id) { return { id: id, name: root.nameOf(id) }; })
                        .sort(function (a, b) { return a.name.localeCompare(b.name); });
                });
                root.candidates = out;
            }
        }
    }

    // Valore attuale di ogni gruppo: "<gruppo>=<id>" una riga per gruppo.
    Process {
        id: query
        command: ["sh", "-c", "for m in " + root.groups.map(function (g) { return g.id + "=" + g.mimes[0]; }).join(" ")
            + '; do printf "%s=%s\\n" "${m%%=*}" "$(xdg-mime query default "${m#*=}" 2>/dev/null)"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                var cur = {};
                text.split("\n").forEach(function (line) {
                    var i = line.indexOf("=");
                    if (i > 0) cur[line.slice(0, i)] = line.slice(i + 1).trim();
                });
                root.current = cur;
                root.busy = false;
            }
        }
    }

    function refresh() {
        if (!scan.running) scan.running = true;
        if (!query.running) { busy = true; query.running = true; }
    }

    function set(groupId, desktopId) {
        if (!validId(desktopId)) return;
        for (var i = 0; i < groups.length; i++) {
            if (groups[i].id !== groupId) continue;
            if (groupId === "web") Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", desktopId]);
            groups[i].mimes.forEach(function (m) { Quickshell.execDetached(["xdg-mime", "default", desktopId, m]); });
        }
        var c = {};
        for (var k in current) c[k] = current[k];
        c[groupId] = desktopId;
        current = c;
        reread.restart();
    }
    Timer { id: reread; interval: 1200; onTriggered: root.refresh() }

    Component.onCompleted: refresh()
}
