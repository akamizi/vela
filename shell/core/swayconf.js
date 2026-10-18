// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Lettura (sola lettura) del config di Sway per mostrare scorciatoie, avvii e regole esistenti
// e riconoscere i conflitti. Non è un parser completo: vale per il file principale, senza include,
// e ignora ciò che sta dentro i blocchi { } (es. le modalità).
.pragma library

function parse(text) {
    var vars = {}, binds = [], execs = [], rules = [];
    var depth = 0;
    text.split("\n").forEach(function (raw) {
        var line = raw.replace(/\s+#.*$/, "").trim();
        if (line === "" || line[0] === "#") return;
        var opens = (line.match(/\{/g) || []).length, closes = (line.match(/\}/g) || []).length;
        var atTop = depth === 0 && opens === 0;
        depth += opens - closes;
        if (depth < 0) depth = 0;
        if (!atTop) return;
        var m;
        if ((m = /^set\s+(\$\S+)\s+(.+)$/.exec(line))) { vars[m[1]] = m[2]; return; }
        if ((m = /^bindsym\s+(.+)$/.exec(line))) {
            var rest = m[1].trim();
            while (rest.indexOf("--") === 0) rest = rest.replace(/^--\S+\s*/, "");   // opzioni: --release, --to-code…
            var sp = rest.search(/\s/);
            if (sp > 0) binds.push({ combo: rest.slice(0, sp), command: rest.slice(sp).trim() });
            return;
        }
        if ((m = /^(exec|exec_always)\s+(.+)$/.exec(line))) { execs.push({ command: m[2].replace(/^--no-startup-id\s+/, ""), always: m[1] === "exec_always" }); return; }
        if ((m = /^for_window\s+(\[[^\]]*\])\s+(.+)$/.exec(line))) rules.push({ criteria: m[1], command: m[2] });
    });
    return { vars: vars, binds: binds, execs: execs, rules: rules };
}

var aliases = { mod4: "super", logo: "super", mod1: "alt", control: "ctrl" };
var modifiers = { super: 1, alt: 1, ctrl: 1, shift: 1, mod2: 1, mod3: 1, mod5: 1 };

// Sostituisce le variabili del config ($mod…) con il loro valore.
function resolve(combo, vars) {
    return combo.replace(/\$[A-Za-z0-9_\-]+/g, function (v) { return vars[v] !== undefined ? vars[v] : v; });
}

// Forma canonica per confrontare due combinazioni: modificatori ordinati, tutto minuscolo.
function normalize(combo, vars) {
    var parts = resolve(combo, vars).split("+").map(function (p) {
        p = p.trim().toLowerCase();
        return aliases[p] || p;
    });
    var mods = parts.filter(function (p) { return modifiers[p]; }).sort();
    var keys = parts.filter(function (p) { return !modifiers[p]; });
    return mods.concat(keys).join("+");
}
