// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Lettura di JSONC (commenti // e /* */, virgole finali) e merge ricorsivo a strati.
.pragma library

// Toglie commenti e virgole finali rispettando le stringhe.
function strip(text) {
    var out = "";
    var i = 0, n = text.length;
    while (i < n) {
        var c = text[i], d = text[i + 1];
        if (c === '"') {
            var j = i + 1;
            while (j < n && text[j] !== '"') j += (text[j] === "\\") ? 2 : 1;
            out += text.slice(i, j + 1);
            i = j + 1;
        } else if (c === "/" && d === "/") {
            while (i < n && text[i] !== "\n") i++;
        } else if (c === "/" && d === "*") {
            var k = text.indexOf("*/", i + 2);
            i = (k < 0) ? n : k + 2;
        } else {
            out += c;
            i++;
        }
    }
    // virgole finali prima di } o ] (le stringhe sono già state ricopiate intatte,
    // ma una stringa contenente ",}" non deve essere toccata: si lavora token per token)
    return stripTrailingCommas(out);
}

function stripTrailingCommas(text) {
    var out = "";
    var i = 0, n = text.length;
    while (i < n) {
        var c = text[i];
        if (c === '"') {
            var j = i + 1;
            while (j < n && text[j] !== '"') j += (text[j] === "\\") ? 2 : 1;
            out += text.slice(i, j + 1);
            i = j + 1;
        } else if (c === ",") {
            var k = i + 1;
            while (k < n && /\s/.test(text[k])) k++;
            if (text[k] !== "}" && text[k] !== "]") out += c;
            i++;
        } else {
            out += c;
            i++;
        }
    }
    return out;
}

function parse(text) {
    return JSON.parse(strip(text));
}

function kind(v) {
    if (v === null) return "null";
    if (Array.isArray(v)) return "array";
    return typeof v;
}

// Merge ricorsivo di `over` su `base`. Gli oggetti si fondono chiave per chiave,
// gli array e i valori semplici sostituiscono. Se il tipo di un valore dell'override
// non coincide con quello del default, l'override per quella chiave è ignorato
// e si aggiunge un avviso. Non modifica gli argomenti.
function merge(base, over, path, warnings) {
    if (kind(over) !== "object") return base;
    var out = {};
    var key;
    for (key in base) out[key] = base[key];
    for (key in over) {
        var p = path ? path + "." + key : key;
        if (!(key in base)) { out[key] = over[key]; continue; }
        var kb = kind(base[key]), ko = kind(over[key]);
        if (kb === "object" && ko === "object") {
            out[key] = merge(base[key], over[key], p, warnings);
        } else if (kb === "null") {
            out[key] = over[key];   // il default null significa "non impostato": accetta qualsiasi tipo
        } else if (kb !== ko) {
            warnings.push(p + ": atteso " + kb + ", trovato " + ko);
        } else {
            out[key] = over[key];
        }
    }
    return out;
}

// --- Menu: merge per id --------------------------------------------------------------
// Il menu è un albero di voci con "id". Nell'override, una voce con un id già presente
// fonde i suoi campi con quella di default (i "children" ricorsivamente); un id nuovo si
// aggiunge in fondo; `"hidden": true` toglie la voce. Gli array di voci non si sostituiscono.
function cloneItem(item) { return JSON.parse(JSON.stringify(item)); }

function mergeItems(base, over, warnings, path) {
    var result = (base || []).map(cloneItem);
    if (kind(over) !== "array") return result;
    for (var i = 0; i < over.length; i++) {
        var u = over[i];
        if (kind(u) !== "object" || typeof u.id !== "string" || u.id === "") {
            warnings.push(path + "[" + i + "]: voce senza id");
            continue;
        }
        var idx = -1;
        for (var j = 0; j < result.length; j++) if (result[j].id === u.id) { idx = j; break; }
        if (idx < 0) {
            if (u.hidden === true) continue;
            // Una voce nuova deve avere un'etichetta e un'azione o dei sottomenu; altrimenti è un errore di scrittura.
            if (typeof u.label !== "string" || (kind(u.action) !== "object" && kind(u.children) !== "array")) {
                warnings.push(path + "." + u.id + ": voce nuova senza label o senza action/children, ignorata");
                continue;
            }
            result.push(cloneItem(u));
        } else if (u.hidden === true) {
            result.splice(idx, 1);
        } else {
            var merged = result[idx];
            for (var k in u) {
                if (k === "children") merged.children = mergeItems(merged.children, u.children, warnings, path + "." + u.id);
                else merged[k] = u[k];
            }
        }
    }
    return result;
}

function mergeMenu(base, over, path, warnings) {
    var out = {};
    for (var key in base) out[key] = base[key];
    out.items = mergeItems(base.items, kind(over) === "object" ? over.items : [], warnings, "items");
    return out;
}
