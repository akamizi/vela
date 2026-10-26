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
console.log("ok swayconf");
