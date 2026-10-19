// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Compone l'elenco delle scorciatoie per il pannello: parte dalle combinazioni di Sway e di Vela,
// ne ricava una descrizione leggibile dal comando e le raggruppa. Nessuna lista scritta a mano delle
// scorciatoie: se cambiano le impostazioni, cambia l'elenco. Un commento in coda alla riga di
// `bindsym` (`# testo`) o un campo "description" nelle scorciatoie di Vela vince sulla descrizione automatica.
.pragma library
.import "swayconf.js" as SwayConf

// Traduzione: la imposta chi chiama (build) con I18n.tr; senza, i testi restano in italiano.
var tr = function (text) {
    var out = text;
    for (var i = 1; i < arguments.length; i++) out = out.split("%" + i).join(String(arguments[i]));
    return out;
};

// Gli identificatori dei gruppi sono italiani (servono a ordinare); si traducono solo per mostrarli.
var groupOrder = ["Applicazioni", "Vela", "Finestre", "Workspace", "Schermo e audio", "Sistema", "Altro"];
function groupLabel(g) {
    switch (g) {
    case "Applicazioni": return tr("Applicazioni");
    case "Vela": return tr("Vela");
    case "Finestre": return tr("Finestre");
    case "Workspace": return tr("Workspace");
    case "Schermo e audio": return tr("Schermo e audio");
    case "Sistema": return tr("Sistema");
    case "Altro": return tr("Altro");
    default: return g;
    }
}

function keyNames() {
    return {
        left: "←", right: "→", up: "↑", down: "↓", return: tr("Invio"), escape: "Esc", space: tr("Spazio"),
        minus: "-", plus: "+", backslash: "\\", slash: "/", comma: ",", period: ".", print: tr("Stamp"),
        prior: tr("PagSu"), next: tr("PagGiù"), grave: "`", equal: "=", bracketleft: "[", bracketright: "]",
        xf86audioraisevolume: tr("Vol+"), xf86audiolowervolume: tr("Vol-"), xf86audiomute: tr("Muto"), xf86audiomicmute: tr("Muto mic"),
        xf86monbrightnessup: tr("Lum+"), xf86monbrightnessdown: tr("Lum-"), xf86display: tr("Schermo")
    };
}
var modLabels = { super: "Super", ctrl: "Ctrl", alt: "Alt", shift: "Shift" };
var modOrder = ["super", "ctrl", "alt", "shift"];
var modAliases = { mod4: "super", logo: "super", mod1: "alt", control: "ctrl" };

// "$mod+Shift+Left" → ["Super", "Shift", "←"] (variabili risolte)
function keycaps(combo, vars) {
    var parts = SwayConf.resolve(combo, vars).split("+").map(function (p) {
        p = p.trim().toLowerCase();
        return modAliases[p] || p;
    });
    var names = keyNames(), mods = [], key = [];
    parts.forEach(function (p) { if (modLabels[p]) mods.push(p); else key.push(p); });
    mods.sort(function (a, b) { return modOrder.indexOf(a) - modOrder.indexOf(b); });
    var out = mods.map(function (m) { return modLabels[m]; });
    key.forEach(function (k) {
        if (k === "") { out.push("+"); return; }
        out.push(names[k] || (k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1)));
    });
    return out;
}

function dirNames() { return { left: tr("a sinistra"), right: tr("a destra"), up: tr("in alto"), down: tr("in basso") }; }
function panelNames() { return { network: tr("Rete"), bluetooth: "Bluetooth", audio: "Audio", settings: tr("Impostazioni"), shortcuts: tr("Scorciatoie"), radio: "Radio", power: tr("Energia") }; }
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
    if (c === "kill") return { label: tr("Chiudi la finestra"), group: "Finestre" };
    if (c === "floating toggle") return { label: tr("Finestra mobile / affiancata"), group: "Finestre" };
    if (/^fullscreen/.test(c)) return { label: tr("Schermo intero"), group: "Finestre" };
    if ((m = /^layout (toggle split|stacking|tabbed|toggle all|default)$/.exec(c)))
        return { label: { "toggle split": tr("Alterna la divisione"), stacking: tr("Layout a pila"), tabbed: tr("Layout a schede"), "toggle all": tr("Scorri i layout"), "default": tr("Layout predefinito") }[m[1]], group: "Finestre" };
    if ((m = /^split (v|h|vertical|horizontal|toggle)/.exec(c)))
        return { label: m[1][0] === "v" ? tr("Dividi in verticale") : m[1][0] === "h" ? tr("Dividi in orizzontale") : tr("Alterna la divisione"), group: "Finestre" };
    if ((m = /^focus (left|right|up|down)$/.exec(c))) return { label: tr("Sposta il focus"), group: "Finestre", series: "focus", part: m[1] };
    if ((m = /^move (left|right|up|down)(\s+\d+(\s*px)?)?$/.exec(c))) return { label: tr("Sposta la finestra"), group: "Finestre", series: "move", part: m[1] };
    if ((m = /^focus (next|prev) sibling$/.exec(c))) return { label: m[1] === "next" ? tr("Finestra successiva") : tr("Finestra precedente"), group: "Finestre" };
    if (/^focus (parent|child|mode_toggle)/.test(c)) return { label: tr("Cambia il focus (%1)", c.slice(6)), group: "Finestre" };
    if (c === "move scratchpad") return { label: tr("Manda allo scratchpad"), group: "Finestre" };
    if (c === "scratchpad show") return { label: tr("Mostra / nascondi lo scratchpad"), group: "Finestre" };
    if ((m = /^resize\s+(shrink|grow)\s+(width|height)/.exec(c)))
        return { label: m[1] === "grow" ? (m[2] === "width" ? tr("Aumenta la larghezza") : tr("Aumenta l'altezza")) : (m[2] === "width" ? tr("Riduci la larghezza") : tr("Riduci l'altezza")), group: "Finestre" };
    if ((m = /^workspace (?:number )?(\S+)$/.exec(c))) {
        if (m[1] === "prev" || m[1] === "prev_on_output") return { label: tr("Workspace precedente"), group: "Workspace" };
        if (m[1] === "next" || m[1] === "next_on_output") return { label: tr("Workspace successivo"), group: "Workspace" };
        if (m[1] === "back_and_forth") return { label: tr("Workspace precedente usato"), group: "Workspace" };
        return { label: tr("Vai al workspace"), group: "Workspace", series: "ws", part: m[1] };
    }
    if ((m = /^move (?:container|window) to workspace (?:number )?(\S+)$/.exec(c))) {
        if (m[1] === "prev" || m[1] === "prev_on_output") return { label: tr("Sposta la finestra al workspace precedente"), group: "Workspace" };
        if (m[1] === "next" || m[1] === "next_on_output") return { label: tr("Sposta la finestra al workspace successivo"), group: "Workspace" };
        return { label: tr("Sposta la finestra al workspace"), group: "Workspace", series: "mv", part: m[1] };
    }
    if ((m = /^mode "?([^"]+)"?$/.exec(c))) return m[1] === "default" ? { label: tr("Torna alla modalità normale"), group: "Sistema" } : { label: tr("Modalità «%1»", m[1]), group: "Sistema" };
    if (c === "reload") return { label: tr("Ricarica la configurazione di Sway"), group: "Sistema" };
    if (/^exit/.test(c)) return { label: tr("Esci da Sway"), group: "Sistema" };

    if ((m = /^exec\s+(.+)$/.exec(c))) {
        var cmd = m[1];
        var ipc = /(?:^|\s|\/)vela\s+ipc\s+call\s+(\S+)\s+(\S+)(?:\s+(\S+))?/.exec(cmd);
        if (ipc) return describeVela(ipc[1], ipc[2], ipc[3] || "");
        if (/\bswaylock\b/.test(cmd)) return { label: tr("Blocca lo schermo"), group: "Sistema" };
        if (/\bwpctl set-volume\b.*\+\s*$/.test(cmd) || /\bwpctl set-volume\b.*\d%\+/.test(cmd)) return { label: tr("Alza il volume"), group: "Schermo e audio" };
        if (/\bwpctl set-volume\b/.test(cmd)) return { label: tr("Abbassa il volume"), group: "Schermo e audio" };
        if (/\bwpctl set-mute\b.*SOURCE/.test(cmd)) return { label: tr("Muto del microfono"), group: "Schermo e audio" };
        if (/\bwpctl set-mute\b/.test(cmd)) return { label: tr("Muto"), group: "Schermo e audio" };
        if (/\bbrightnessctl\b.*\+/.test(cmd)) return { label: tr("Aumenta la luminosità"), group: "Schermo e audio" };
        if (/\bbrightnessctl\b/.test(cmd)) return { label: tr("Riduci la luminosità"), group: "Schermo e audio" };
        if (/output \S+ power/.test(cmd)) return { label: tr("Accendi / spegni lo schermo"), group: "Schermo e audio" };
        var ep = execProgram(cmd), args = ep.rest;
        if (args.length > 28) args = args.slice(0, 27) + "…";
        return { label: ep.prog === "" ? cmd : ep.prog, group: "Applicazioni", program: ep.prog, args: args };
    }
    return { label: c, group: "Altro" };
}

function describeVela(target, fn, arg) {
    var v = "Vela";
    if (target === "menu") return { label: fn === "apps" ? tr("Applicazioni") : fn === "toggle" ? tr("Menu") : tr("Menu (%1)", fn), group: v };
    if (target === "bar") return { label: tr("Mostra / nascondi la barra"), group: v };
    if (target === "panel") {
        var name = arg || "";
        return { label: fn === "close" ? tr("Chiudi il pannello") : tr("Pannello %1", panelNames()[name] || name), group: v };
    }
    if (target === "toggles") return { label: ({ awake: tr("Resta sveglio"), night: tr("Luce notturna"), dnd: tr("Non disturbare") })[fn] || tr("Interruttore %1", fn), group: v };
    if (target === "idle") return { label: fn === "lock" ? tr("Blocca lo schermo") : fn === "suspend" ? tr("Sospendi") : tr("Inattività (%1)", fn), group: "Sistema" };
    return { label: tr("Vela: %1 %2", target, fn), group: v };
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
            return { label: it.label + " " + (dirNames()[g.parts[0]] || g.parts[0]), group: it.group, keys: it.keys, key: it.key };
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
// resolveName(programma) → nome dell'applicazione (facoltativo); translate = I18n.tr (facoltativo).
function build(parsed, own, resolveName, translate) {
    if (translate) tr = translate;
    var vars = parsed.vars;
    var taken = {}, items = [];

    function add(combo, command, desc, group) {
        var n = SwayConf.normalize(combo, vars);
        if (taken[n]) return;
        taken[n] = true;
        if (!command || command.trim() === "") return;
        var d = describeCommand(command, vars);
        if (desc) { d.label = desc; d.series = undefined; }
        else if (d.program && resolveName) { var nm = resolveName(d.program); if (nm) d.label = nm; else d.label = tr("Avvia %1", d.program + (d.args ? " " + d.args : "")); }
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
        rows.push({ kind: "header", label: groupLabel(g), key: "h:" + g });
        list.forEach(function (it) { rows.push({ kind: "bind", label: it.label, keys: it.keys, tail: it.tail || "", key: it.key }); });
    });

    // Modalità (es. resize): una sezione ciascuna, con i propri tasti.
    var modes = {};
    (parsed.modeBinds || []).forEach(function (b) {
        var d = describeCommand(b.command, vars);
        (modes[b.mode] = modes[b.mode] || []).push({ label: b.desc || d.label, group: b.mode, keys: keycaps(b.combo, vars), key: "m:" + b.mode + ":" + b.combo });
    });
    Object.keys(modes).forEach(function (name) {
        rows.push({ kind: "header", label: tr("Modalità «%1»", name), key: "hm:" + name });
        mergeSame(modes[name]).forEach(function (it) { rows.push({ kind: "bind", label: it.label, keys: it.keys, tail: "", key: it.key }); });
    });
    return rows;
}
