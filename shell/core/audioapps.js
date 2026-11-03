// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
.pragma library

// Volume per applicazione (D-067). Logica pura: il raggruppamento dei flussi PipeWire e il calcolo dei volumi per canale.
// Un flusso è { id, binary, appName, nodeName, volumes: [per canale], muted }.

// Chiave di raggruppamento: il binario, poi il nome dell'app, poi il nome del nodo (più flussi della stessa app, per esempio le
// schede di un browser, formano una riga sola).
function keyOf(s) { return s.binary || s.appName || s.nodeName || ("id" + s.id); }

function mean(vols) {
    if (!vols || vols.length === 0) return 0;
    var t = 0;
    for (var i = 0; i < vols.length; i++) t += vols[i];
    return t / vols.length;
}

// Raggruppa i flussi: una riga per app, con il volume più alto del gruppo, muta solo se tutti i flussi lo sono. Ordine alfabetico.
function group(streams) {
    // Mappa senza prototipo: la chiave la dichiara l'app (`constructor`, `__proto__`, `toString` non devono trovare nulla di ereditato)
    var by = Object.create(null), order = [];
    streams.forEach(function (s) {
        var k = keyOf(s);
        if (!by[k]) { by[k] = { key: k, name: s.appName || s.binary || s.nodeName || k, streams: [] }; order.push(k); }
        // Il nome più descrittivo tra quelli del gruppo: quello dell'app, se un flusso lo ha
        if (s.appName && !by[k].named) { by[k].name = s.appName; by[k].named = true; }
        by[k].streams.push(s);
    });
    var out = order.map(function (k) {
        var g = by[k];
        return { key: g.key, name: g.name, ids: g.streams.map(function (s) { return s.id; }),
                 volume: Math.max.apply(null, g.streams.map(function (s) { return mean(s.volumes); })),
                 muted: g.streams.every(function (s) { return s.muted; }) };
    });
    out.sort(function (a, b) { return a.name.localeCompare(b.name); });
    return out;
}

// Nuovi volumi per canale perché la media diventi `target`, conservando il bilanciamento tra i canali. Ogni canale è limitato a
// [0, max]. Con volume attuale nullo non c'è un bilanciamento da conservare: tutti i canali al valore.
function scaled(volumes, target, max) {
    var t = Math.max(0, Math.min(max, target));
    var avg = mean(volumes);
    if (!volumes || volumes.length === 0) return [];
    if (avg <= 0) return volumes.map(function () { return t; });
    return volumes.map(function (v) { return Math.max(0, Math.min(max, v * t / avg)); });
}
