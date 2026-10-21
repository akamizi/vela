// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Servizi runit (D-047): stato di un elenco configurabile di servizi e azioni (avvia, ferma, riavvia, abilita, disabilita).
// Sicurezza: Vela non esegue operazioni privilegiate e non vede password. Le azioni si lanciano in un terminale con `doas` (o `sudo`),
// che chiede la password all'utente ogni volta. Lo stato non richiede privilegi: `sv status` è riservato a root (la cartella supervise
// non è leggibile), quindi si deduce da due fatti pubblici: il servizio è collegato in /var/service (abilitato) e il suo processo esiste (pgrep).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    readonly property var cfg: Config.shell.services
    property bool available: false        // runit presente: /var/service esiste
    property var items: []                // [{id, label, process, installed, enabled, running}]
    property string status: ""            // messaggio dell'ultima azione

    function validName(n) { return typeof n === "string" && /^[A-Za-z0-9_.\-]+$/.test(n); }
    function entries() {
        var l = cfg && Array.isArray(cfg.list) ? cfg.list : [];
        return l.filter(function (e) { return e && validName(e.id) && typeof e.label === "string"; })
                .map(function (e) { return { id: e.id, label: e.label, process: validName(e.process) ? e.process : e.id }; });
    }

    // Una lettura per ciclo: per ogni servizio "id:processo" -> installato (/etc/sv), abilitato (/var/service), in esecuzione (pgrep).
    // pgrep -x confronta il nome del processo troncato a 15 caratteri.
    function parse(text) {
        var byId = {};
        text.split("\n").forEach(function (l) {
            var f = l.trim().split(" ");
            if (f.length === 4) byId[f[0]] = { installed: f[1] === "1", enabled: f[2] === "1", running: f[3] === "1" };
        });
        items = entries().map(function (e) {
            var s = byId[e.id] || { installed: false, enabled: false, running: false };
            return { id: e.id, label: e.label, process: e.process, installed: s.installed, enabled: s.enabled, running: s.running };
        }).filter(function (e) { return e.installed; });
        available = true;
    }
    Process {
        id: poll
        command: ["sh", "-c",
            '[ -d /var/service ] || exit 0; for a in "$@"; do s=${a%%:*}; p=${a#*:}; p=$(printf %s "$p" | cut -c1-15); i=0; e=0; r=0;'
            + ' [ -d "/etc/sv/$s" ] && i=1; [ -e "/var/service/$s" ] && e=1; pgrep -x "$p" >/dev/null 2>&1 && r=1; echo "$s $i $e $r"; done',
            "sh"].concat(root.entries().map(function (e) { return e.id + ":" + e.process; }))
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    function refresh() { if (!poll.running) poll.running = true; }
    Component.onCompleted: refresh()

    // Azioni: terminal + script fisso con il nome come argomento posizionale (mai interpolato nella stringa dello script).
    readonly property var actions: ["start", "stop", "restart", "enable", "disable"]
    readonly property string script:
        'run() { if command -v doas >/dev/null 2>&1; then doas "$@"; else sudo "$@"; fi; };'
        + ' case "$1" in'
        + ' enable) run ln -s "/etc/sv/$2" "/var/service/$2";;'
        + ' disable) run rm "/var/service/$2";;'
        + ' *) run sv "$1" "$2";; esac;'
        + ' printf "\\nInvio per chiudere… "; read _'

    function known(id) { return items.some(function (e) { return e.id === id; }); }
    function act(action, id) {
        if (runner.running || actions.indexOf(action) < 0 || !known(id)) return false;
        var term = cfg && Array.isArray(cfg.terminal) && cfg.terminal.every(function (x) { return typeof x === "string"; }) && cfg.terminal.length > 0
            ? cfg.terminal : ["foot", "-e"];
        runner.command = term.concat(["sh", "-c", script, "sh", action, id]);
        runner.running = true;
        return true;
    }
    Process {
        id: runner
        onExited: root.refresh()      // a terminale chiuso si rilegge lo stato
    }
    readonly property bool busy: runner.running
}
