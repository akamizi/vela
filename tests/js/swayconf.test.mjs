// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load } from "./run.mjs";

const sc = load("shell/core/swayconf.js");

// bindcode conta come scorciatoia (conflitti con i tasti in più: il tasto Copilot è un bindcode)
const p = sc.parse("set $mod Mod4\nbindcode $mod+Shift+201 exec miofm\nbindsym $mod+t exec foot\nbindcode --release 99 exec x\n");
assert.strictEqual(p.binds.length, 3);
assert.strictEqual(sc.normalize(p.binds[0].combo, p.vars), sc.normalize("Mod4+Shift+201", {}));
assert.strictEqual(p.binds[0].command, "exec miofm");
assert.strictEqual(p.binds[2].combo, "99");
// dentro una modalità
const m = sc.parse("mode \"resize\" {\n  bindcode 113 resize shrink width 20px\n}\n");
assert.strictEqual(m.modeBinds.length, 1);

// Valori che finiscono in un comando di Sway: la virgola e il «;» separano i comandi, «#» apre un commento
assert.strictEqual(sc.safe("1920x1080@60Hz"), true);
assert.strictEqual(sc.safe("/home/u/Immagini/sfondo uno.png"), true);
for (const bad of ["a, exec foot", "a,b", "a;b", "#abc", "a\nb", 'a"b', "a$b", 5, null]) assert.strictEqual(sc.safe(bad), false, String(bad));
// Liste XKB: la virgola separa gli elementi (legittimo), ma ogni elemento è una sola parola
assert.strictEqual(sc.safeList("us,it"), true);
assert.strictEqual(sc.safeList("ctrl:nocaps,compose:ralt"), true);
assert.strictEqual(sc.safeList(",intl"), true);          // variante vuota per il primo layout
assert.strictEqual(sc.safeList("ctrl:nocaps, exec foot"), false);
assert.strictEqual(sc.safeList("us,it;exec foot"), false);
assert.strictEqual(sc.safeList("us #x"), false);
assert.strictEqual(sc.safeList(7), false);
console.log("ok swayconf");
