// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Compone l'elenco delle scorciatoie per il pannello: parte dalle combinazioni di Sway e di Vela,
// ne ricava una descrizione leggibile dal comando e le raggruppa. Nessuna lista scritta a mano delle
// scorciatoie: se cambiano le impostazioni, cambia l'elenco. Un commento in coda alla riga di
// `bindsym` (`# testo`) o un campo "description" nelle scorciatoie di Vela vince sulla descrizione automatica.
.pragma library
.import "swayconf.js" as SwayConf

var groupOrder = ["Applicazioni", "Vela", "Finestre", "Workspace", "Schermo e audio", "Sistema", "Altro"];

var keyNames = {
    left: "←", right: "→", up: "↑", down: "↓", return: "Invio", escape: "Esc", space: "Spazio",
    minus: "-", plus: "+", backslash: "\\", slash: "/", comma: ",", period: ".", print: "Stamp",
    prior: "PagSu", next: "PagGiù", grave: "`", equal: "=", bracketleft: "[", bracketright: "]",
    xf86audioraisevolume: "Vol+", xf86audiolowervolume: "Vol-", xf86audiomute: "Muto", xf86audiomicmute: "Muto mic",
    xf86monbrightnessup: "Lum+", xf86monbrightnessdown: "Lum-", xf86display: "Schermo"
};
var modLabels = { super: "Super", ctrl: "Ctrl", alt: "Alt", shift: "Shift" };
var modOrder = ["super", "ctrl", "alt", "shift"];
var modAliases = { mod4: "super", logo: "super", mod1: "alt", control: "ctrl" };

// "$mod+Shift+Left" → ["Super", "Shift", "←"] (variabili risolte)
function keycaps(combo, vars) {
    var parts = SwayConf.resolve(combo, vars).split("+").map(function (p) {
        p = p.trim().toLowerCase();
        return modAliases[p] || p;
    });
    var mods = [], key = [];
    parts.forEach(function (p) { if (modLabels[p]) mods.push(p); else key.push(p); });
    mods.sort(function (a, b) { return modOrder.indexOf(a) - modOrder.indexOf(b); });
    var out = mods.map(function (m) { return modLabels[m]; });
    key.forEach(function (k) {
        if (k === "") { out.push("+"); return; }
        out.push(keyNames[k] || (k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1)));
    });
    return out;
}

var dirNames = { left: "a sinistra", right: "a destra", up: "in alto", down: "in basso" };
var panelNames = { network: "Rete", bluetooth: "Bluetooth", audio: "Audio", settings: "Impostazioni", shortcuts: "Scorciatoie" };
var terminals = ["foot", "alacritty", "kitty", "wezterm", "xterm", "st", "footclient"];

function base(path) { return path.replace(/^.*\//, ""); }

// Comando exec: programma (saltando opzioni e variabili) e argomenti; per un terminale con `-e` vale il comando che lancia.
function execProgram(cmd) {
    var words = cmd.match(/"[^"]*"|'[^']*'|\S+/g) || [];
    var i = 0;
    while (i < words.length && /^(--\S+|env|[A-Z_]+=\S*)$/.test(words[i])) i++;
    var prog = words[i] ? base(words[i].replace(/["']/g, "")) : "";
    if (terminals.indexOf(prog) >= 0) {
        var e = words.indexOf("-e");
        if (e >= 0 && words[e + 1]) { i = e + 1; prog = base(words[i].replace(/["']/g, "")); }
    }
    return { prog: prog, rest: words.slice(i + 1).join(" ").replace(/["']/g, "") };
}

// {label, group, series?, part?}: series raggruppa più combinazioni dello stesso comando (workspace 1…9, frecce).
function describeCommand(command, vars) {
    var c = SwayConf.resolve(command, vars).trim().replace(/^--no-startup-id\s+/, "");
    var m;
    if (c === "kill") return { label: "Chiudi la finestra", group: "Finestre" };
    if (c === "floating toggle") return { label: "Finestra mobile / affiancata", group: "Finestre" };
    if (/^fullscreen/.test(c)) return { label: "Schermo intero", group: "Finestre" };
    if ((m = /^layout (toggle split|stacking|tabbed|toggle all|default)$/.exec(c)))
        return { label: { "toggle split": "Alterna la divisione", stacking: "Layout a pila", tabbed: "Layout a schede", "toggle all": "Scorri i layout", "default": "Layout predefinito" }[m[1]], group: "Finestre" };
    if ((m = /^split (v|h|vertical|horizontal|toggle)/.exec(c)))
        return { label: m[1][0] === "v" ? "Dividi in verticale" : m[1][0] === "h" ? "Dividi in orizzontale" : "Alterna la divisione", group: "Finestre" };
    if ((m = /^focus (left|right|up|down)$/.exec(c))) return { label: "Sposta il focus", group: "Finestre", series: "focus", part: m[1] };
    if ((m = /^move (left|right|up|down)(\s+\d+(\s*px)?)?$/.exec(c))) return { label: "Sposta la finestra", group: "Finestre", series: "move", part: m[1] };
    if ((m = /^focus (next|prev) sibling$/.exec(c))) return { label: m[1] === "next" ? "Finestra successiva" : "Finestra precedente", group: "Finestre" };
    if (/^focus (parent|child|mode_toggle)/.test(c)) return { label: "Cambia il focus (" + c.slice(6) + ")", group: "Finestre" };
    if (c === "move scratchpad") return { label: "Manda allo scratchpad", group: "Finestre" };
    if (c === "scratchpad show") return { label: "Mostra / nascondi lo scratchpad", group: "Finestre" };
    if ((m = /^resize\s+(shrink|grow)\s+(width|height)/.exec(c)))
        return { label: (m[1] === "grow" ? "Aumenta " : "Riduci ") + (m[2] === "width" ? "la larghezza" : "l'altezza"), group: "Finestre" };
    if ((m = /^workspace (?:number )?(\S+)$/.exec(c))) {
        if (m[1] === "prev" || m[1] === "prev_on_output") return { label: "Workspace precedente", group: "Workspace" };
        if (m[1] === "next" || m[1] === "next_on_output") return { label: "Workspace successivo", group: "Workspace" };
        if (m[1] === "back_and_forth") return { label: "Workspace precedente usato", group: "Workspace" };
        return { label: "Vai al workspace", group: "Workspace", series: "ws", part: m[1] };
    }
    if ((m = /^move (?:container|window) to workspace (?:number )?(\S+)$/.exec(c))) {
        if (m[1] === "prev" || m[1] === "prev_on_output") return { label: "Sposta la finestra al workspace precedente", group: "Workspace" };
        if (m[1] === "next" || m[1] === "next_on_output") return { label: "Sposta la finestra al workspace successivo", group: "Workspace" };
        return { label: "Sposta la finestra al workspace", group: "Workspace", series: "mv", part: m[1] };
    }
    if ((m = /^mode "?([^"]+)"?$/.exec(c))) return m[1] === "default" ? { label: "Torna alla modalità normale", group: "Sistema" } : { label: "Modalità «" + m[1] + "»", group: "Sistema" };
    if (c === "reload") return { label: "Ricarica la configurazione di Sway", group: "Sistema" };
    if (/^exit/.test(c)) return { label: "Esci da Sway", group: "Sistema" };

    if ((m = /^exec\s+(.+)$/.exec(c))) {
        var cmd = m[1];
        var ipc = /(?:^|\s|\/)vela\s+ipc\s+call\s+(\S+)\s+(\S+)(?:\s+(\S+))?/.exec(cmd);
        if (ipc) return describeVela(ipc[1], ipc[2], ipc[3] || "");
        if (/\bswaylock\b/.test(cmd)) return { label: "Blocca lo schermo", group: "Sistema" };
        if (/\bwpctl set-volume\b.*\+\s*$/.test(cmd) || /\bwpctl set-volume\b.*\d%\+/.test(cmd)) return { label: "Alza il volume", group: "Schermo e audio" };
        if (/\bwpctl set-volume\b/.test(cmd)) return { label: "Abbassa il volume", group: "Schermo e audio" };
        if (/\bwpctl set-mute\b.*SOURCE/.test(cmd)) return { label: "Muto del microfono", group: "Schermo e audio" };
        if (/\bwpctl set-mute\b/.test(cmd)) return { label: "Muto", group: "Schermo e audio" };
        if (/\bbrightnessctl\b.*\+/.test(cmd)) return { label: "Aumenta la luminosità", group: "Schermo e audio" };
        if (/\bbrightnessctl\b/.test(cmd)) return { label: "Riduci la luminosità", group: "Schermo e audio" };
        if (/output \S+ power/.test(cmd)) return { label: "Accendi / spegni lo schermo", group: "Schermo e audio" };
        var ep = execProgram(cmd), args = ep.rest;
        if (args.length > 28) args = args.slice(0, 27) + "…";
        return { label: ep.prog === "" ? cmd : ep.prog, group: "Applicazioni", program: ep.prog, args: args };
    }
    return { label: c, group: "Altro" };
}

function describeVela(target, fn, arg) {
    var v = "Vela";
    if (target === "menu") return { label: fn === "apps" ? "Applicazioni" : fn === "toggle" ? "Menu" : "Menu (" + fn + ")", group: v };
    if (target === "bar") return { label: "Mostra / nascondi la barra", group: v };
    if (target === "panel") {
        var name = arg || "";
        return { label: fn === "close" ? "Chiudi il pannello" : "Pannello " + (panelNames[name] || name), group: v };
    }
    if (target === "toggles") return { label: ({ awake: "Resta sveglio", night: "Luce notturna", dnd: "Non disturbare" })[fn] || ("Interruttore " + fn), group: v };
    if (target === "idle") return { label: fn === "lock" ? "Blocca lo schermo" : fn === "suspend" ? "Sospendi" : "Inattività (" + fn + ")", group: "Sistema" };
    return { label: "Vela: " + target + " " + fn, group: v };
}

// "1","2","3" → "1…3"; altrimenti i tasti uno dopo l'altro ("← → ↑ ↓").
function rangeLabel(caps) {
    if (caps.every(function (p) { return /^\d+$/.test(p); })) {
        var n = caps.map(Number).sort(function (a, b) { return a - b; });
        if (n.length > 2 && n.every(function (x, i) { return i === 0 || x === n[i - 1] + 1; })) return n[0] + "…" + n[n.length - 1];
    }
    var arrows = "←→↑↓";
    if (caps.every(function (p) { return arrows.indexOf(p) >= 0 && p.length === 1; }))
        return caps.slice().sort(function (a, b) { return arrows.indexOf(a) - arrows.indexOf(b); }).join(" ");
    return caps.join(" ");
}

// Unisce le voci della stessa serie (stesso comando, stessi modificatori): "Super 1…9" invece di nove righe.
function collapse(items) {
    var out = [], seen = {};
    items.forEach(function (it) {
        if (!it.series) { out.push(it); return; }
        var mods = it.keys.slice(0, -1), id = it.series + "|" + mods.join("+");
        if (seen[id] === undefined) { seen[id] = out.length; out.push({ first: it, mods: mods, caps: [], parts: [] }); }
        var g = out[seen[id]];
        g.caps.push(it.keys[it.keys.length - 1]);
        g.parts.push(it.part);
    });
    return out.map(function (g) {
        if (!g.first) return g;
        var it = g.first;
        if (g.caps.length === 1)
            return { label: it.label + " " + (dirNames[g.parts[0]] || g.parts[0]), group: it.group, keys: it.keys, key: it.key };
        return { label: it.label, group: it.group, keys: g.mods, tail: rangeLabel(g.caps), key: it.key };
    });
}

// Più combinazioni per la stessa azione (stesso gruppo e stessa etichetta) diventano una riga sola: "A / B".
var SEP = "|sep|";
function mergeSame(list) {
    var out = [], seen = {};
    list.forEach(function (it) {
        if (it.tail) { out.push(it); return; }
        var id = it.group + "|" + it.label;
        if (seen[id] === undefined) { seen[id] = out.length; out.push(it); return; }
        var t = out[seen[id]];
        t.keys = t.keys.concat([SEP], it.keys);
    });
    return out;
}

// Dalle scorciatoie dell'utente (config di Sway, quelle di Vela, quelle delle modalità) alle righe del pannello.
// own: [{combo, command, description?}] — hanno la precedenza e quelle con comando vuoto tolgono la combinazione.
// resolveName(programma) → nome dell'applicazione (facoltativo).
function build(parsed, own, resolveName) {
    var vars = parsed.vars;
    var taken = {}, items = [];

    function add(combo, command, desc, group) {
        var n = SwayConf.normalize(combo, vars);
        if (taken[n]) return;
        taken[n] = true;
        if (!command || command.trim() === "") return;
        var d = describeCommand(command, vars);
        if (desc) { d.label = desc; d.series = undefined; }
        else if (d.program && resolveName) { var nm = resolveName(d.program); if (nm) d.label = nm; else d.label = "Avvia " + d.program + (d.args ? " " + d.args : ""); }
        if (group) d.group = group;
        items.push({ label: d.label, group: d.group, series: d.series, part: d.part, keys: keycaps(combo, vars), key: "b:" + n });
    }

    (own || []).forEach(function (b) { add(b.combo, b.command, b.description, ""); });
    parsed.binds.forEach(function (b) { add(b.combo, b.command, b.desc, ""); });

    var rows = [];
    var collapsed = mergeSame(collapse(items));
    groupOrder.forEach(function (g) {
        var list = collapsed.filter(function (it) { return it.group === g; });
        if (list.length === 0) return;
        rows.push({ kind: "header", label: g, key: "h:" + g });
        list.forEach(function (it) { rows.push({ kind: "bind", label: it.label, keys: it.keys, tail: it.tail || "", key: it.key }); });
    });

    // Modalità (es. resize): una sezione ciascuna, con i propri tasti.
    var modes = {};
    (parsed.modeBinds || []).forEach(function (b) {
        var d = describeCommand(b.command, vars);
        (modes[b.mode] = modes[b.mode] || []).push({ label: b.desc || d.label, group: b.mode, keys: keycaps(b.combo, vars), key: "m:" + b.mode + ":" + b.combo });
    });
    Object.keys(modes).forEach(function (name) {
        rows.push({ kind: "header", label: "Modalità «" + name + "»", key: "hm:" + name });
        mergeSame(modes[name]).forEach(function (it) { rows.push({ kind: "bind", label: it.label, keys: it.keys, tail: "", key: it.key }); });
    });
    return rows;
}
