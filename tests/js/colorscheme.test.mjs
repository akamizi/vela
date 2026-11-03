// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load } from "./run.mjs";

const cs = load("shell/core/colorscheme.js");

// Luminanza: nero 0, bianco 1, forme equivalenti dello stesso colore, testo non valido
assert.strictEqual(cs.luminance("#000000"), 0);
assert.ok(Math.abs(cs.luminance("#ffffff") - 1) < 1e-9);
assert.strictEqual(cs.luminance("#fff"), cs.luminance("#ffffff"));
assert.strictEqual(cs.luminance("#1a1a1add"), cs.luminance("#1a1a1a"));   // l'alfa non conta
for (const bad of ["", "nero", "#12", "#12345", "rgb(0,0,0)", null, undefined]) assert.strictEqual(cs.luminance(bad), -1, String(bad));

// Tema predefinito di Vela (sfondo #1a1a1a, testo #e4e5e6): scuro
assert.strictEqual(cs.schemeFor("#1a1a1a", "#e4e5e6"), "prefer-dark");
// Tema chiaro: sfondo chiaro, testo scuro
assert.strictEqual(cs.schemeFor("#fafafa", "#202020"), "prefer-light");
// Conta il confronto tra i due, non una soglia: un grigio medio con testo bianco è scuro, con testo nero chiaro
assert.strictEqual(cs.schemeFor("#808080", "#ffffff"), "prefer-dark");
assert.strictEqual(cs.schemeFor("#808080", "#000000"), "prefer-light");
// Colori invalidi o uguali: non si decide
assert.strictEqual(cs.schemeFor("rosso", "#ffffff"), null);
assert.strictEqual(cs.schemeFor("#ffffff", undefined), null);
assert.strictEqual(cs.schemeFor("#777777", "#777777"), null);

// Valore letto da gsettings
assert.strictEqual(cs.cleanValue("'prefer-dark'\n"), "prefer-dark");
assert.strictEqual(cs.cleanValue("'default'"), "default");
assert.strictEqual(cs.cleanValue("niente apici"), "niente apici");
console.log("colorscheme: ok");
