// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Menu dichiarativo (config/defaults/menu.jsonc + override per id): visibilità, ricerca e azioni.
// Le azioni sono dati, mai stringhe da passare a una shell: `exec` è sempre un array di argomenti.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    readonly property var items: Config.menu.items
    // Pannelli abilitati in configurazione e realmente presenti (si aggiungono nelle fasi 4-6)
    readonly property var implementedPanels: ["network", "bluetooth", "audio", "settings", "shortcuts", "radio", "power", "brightness"]
    readonly property var availablePanels: implementedPanels.filter(function (n) {
        var c = Config.shell.panels[n];
        return c !== undefined && c.enabled === true;
    })

    // --- comandi richiesti (`requires`): una voce con un comando assente non compare ---
    property var found: ({})

    function collect(list, out) {
        for (var i = 0; i < list.length; i++) {
            var r = list[i].requires;
            if (Array.isArray(r)) for (var j = 0; j < r.length; j++) if (out.indexOf(r[j]) < 0) out.push(r[j]);
            if (list[i].children) collect(list[i].children, out);
        }
        return out;
    }
    readonly property var required: collect(items, [])

    Process {
        id: probe
        command: ["sh", "-c", 'for c in "$@"; do command -v "$c" >/dev/null 2>&1 && echo "$c"; done', "sh"].concat(root.required)
        running: root.required.length > 0
        stdout: StdioCollector {
            onStreamFinished: {
                var m = {};
                text.split("\n").forEach(function (n) { if (n !== "") m[n] = true; });
                root.found = m;
            }
        }
    }

    function isSubmenu(item) { return Array.isArray(item.children); }

    function usable(item) {
        if (item.hidden === true) return false;
        var r = item.requires;
        if (Array.isArray(r)) for (var i = 0; i < r.length; i++) if (!found[r[i]]) return false;
        var a = item.action;
        if (a && a.type === "panel" && availablePanels.indexOf(a.target) < 0) return false;
        return true;
    }

    // Voci visibili di un elenco; un sottomenu senza voci visibili sparisce.
    function visible(list) {
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var it = list[i];
            if (!usable(it)) continue;
            if (isSubmenu(it) && visible(it.children).length === 0) continue;
            out.push(it);
        }
        return out;
    }

    // Voci del livello indicato da `path` (array di id); [] se il percorso non esiste più.
    function level(path) {
        var list = items;
        for (var i = 0; i < path.length; i++) {
            var next = null;
            for (var j = 0; j < list.length; j++) if (list[j].id === path[i]) { next = list[j]; break; }
            if (!next || !isSubmenu(next)) return [];
            list = next.children;
        }
        return visible(list);
    }

    function find(path) {
        var list = items, cur = null;
        for (var i = 0; i < path.length; i++) {
            cur = null;
            for (var j = 0; j < list.length; j++) if (list[j].id === path[i]) { cur = list[j]; break; }
            if (!cur) return null;
            list = cur.children || [];
        }
        return cur;
    }

    // Tutte le voci eseguibili (foglie), con etichetta di percorso, per la ricerca.
    function leaves() {
        var out = [];
        (function walk(list, labels) {
            var vis = visible(list);
            for (var i = 0; i < vis.length; i++) {
                var it = vis[i], here = labels.concat([I18n.tr(it.label)]);
                if (isSubmenu(it)) walk(it.children, here);
                else out.push({ item: it, label: I18n.tr(it.label), sub: labels.join(" › ") });
            }
        })(items, []);
        return out;
    }

    function checked(item) {
        var a = item.action;
        if (!a || a.type !== "toggle") return null;
        switch (a.target) {
        case "night": return Toggles.night;
        case "awake": return Toggles.awakeOn;
        case "dnd": return Toggles.dnd;
        case "bar": return Runtime.barVisible;
        }
        return null;
    }

    function validCommand(c) {
        return Array.isArray(c) && c.length > 0 && c.every(function (x) { return typeof x === "string"; });
    }

    // Esegue una voce. Restituisce false se l'azione non è valida.
    function run(item) {
        var a = item.action;
        if (!a) return false;
        switch (a.type) {
        case "exec":
            if (!validCommand(a.command)) { console.warn("[vela] menu: comando non valido in '" + item.id + "'"); return false; }
            Quickshell.execDetached(a.command);
            return true;
        case "toggle":
            if (a.target === "night") Toggles.toggleNight();
            else if (a.target === "awake") Toggles.toggleAwake();
            else if (a.target === "dnd") Toggles.toggleDnd();
            else if (a.target === "bar") Runtime.barVisible = !Runtime.barVisible;
            else return false;
            return true;
        case "panel":
            Runtime.openPanel(a.target);
            return true;
        case "compositor":
            return Compositor.run(a.command);
        }
        console.warn("[vela] menu: tipo di azione sconosciuto in '" + item.id + "': " + a.type);
        return false;
    }
}
