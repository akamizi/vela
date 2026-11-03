// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load, plain } from "./run.mjs";

const a = load("shell/core/audioapps.js");

// Chiave: binario, poi nome app, poi nome nodo
assert.strictEqual(a.keyOf({ id: 1, binary: "firefox", appName: "Firefox", nodeName: "x" }), "firefox");
assert.strictEqual(a.keyOf({ id: 1, appName: "Firefox", nodeName: "x" }), "Firefox");
assert.strictEqual(a.keyOf({ id: 1, nodeName: "x" }), "x");
assert.strictEqual(a.keyOf({ id: 7 }), "id7");

// Due schede dello stesso browser: una riga sola, volume più alto, muta solo se tutte lo sono
let g = plain(a.group([
    { id: 10, binary: "firefox", appName: "Firefox", volumes: [0.4, 0.4], muted: true },
    { id: 11, binary: "firefox", appName: "Firefox", volumes: [0.8, 0.6], muted: false },
    { id: 12, binary: "mpv", appName: "mpv Media Player", volumes: [1, 1], muted: false },
]));
assert.strictEqual(g.length, 2);
assert.deepStrictEqual(g.map(x => x.name), ["Firefox", "mpv Media Player"]);
assert.deepStrictEqual(g[0].ids, [10, 11]);
assert.ok(Math.abs(g[0].volume - 0.7) < 1e-9);
assert.strictEqual(g[0].muted, false);
g = plain(a.group([{ id: 1, binary: "x", volumes: [0.5], muted: true }, { id: 2, binary: "x", volumes: [0.5], muted: true }]));
assert.strictEqual(g[0].muted, true);
assert.strictEqual(g[0].name, "x");          // senza nome dell'app si usa il binario
assert.deepStrictEqual(plain(a.group([])), []);

// Volumi per canale: la media diventa il valore, il bilanciamento si conserva
let v = a.scaled([0.8, 0.4], 0.3, 1);          // media 0,6 -> 0,3: tutto dimezzato
assert.ok(Math.abs(v[0] - 0.4) < 1e-9 && Math.abs(v[1] - 0.2) < 1e-9);
v = a.scaled([1, 0.2], 1, 1);                   // un canale supererebbe il massimo: si limita
assert.ok(v[0] <= 1 && v[1] <= 1);
assert.deepStrictEqual(plain(a.scaled([0, 0], 0.5, 1)), [0.5, 0.5]);   // da zero: tutti uguali
assert.deepStrictEqual(plain(a.scaled([0.5, 0.5], -1, 1)), [0, 0]);    // mai sotto zero
assert.deepStrictEqual(plain(a.scaled([], 0.5, 1)), []);
console.log("audioapps: ok");
