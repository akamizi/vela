// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Ricerca fuzzy per sottosequenza, senza maiuscole e senza accenti.
.pragma library

function norm(s) {
    return String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
}

var SEPARATORS = " -_/.›:";

// Punteggio di `query` dentro `text`; -1 se non corrisponde. Più alto = migliore.
// Premia i caratteri consecutivi, gli inizi di parola e i testi corti.
function score(query, text) {
    var q = norm(query), t = norm(text);
    if (q === "") return 0;
    var pos = 0, last = -2, run = 0, s = 0, first = -1;
    for (var i = 0; i < q.length; i++) {
        var idx = t.indexOf(q[i], pos);
        if (idx < 0) return -1;
        if (first < 0) first = idx;
        s += 1;
        if (idx === last + 1) { run++; s += 2 * run; } else run = 0;
        if (idx === 0 || SEPARATORS.indexOf(t[idx - 1]) >= 0) s += 3;
        last = idx;
        pos = idx + 1;
    }
    // Caratteri troppo sparpagliati non sono una corrispondenza (evita falsi positivi nei testi lunghi).
    if (last - first + 1 > q.length * 2) return -1;
    if (t.indexOf(q) === 0) s += 10;
    return s - first * 0.1 - t.length * 0.05;
}
