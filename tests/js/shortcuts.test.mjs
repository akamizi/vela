// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load } from "./run.mjs";

const sc = load("shell/core/swayconf.js");
const sh = load("shell/core/shortcuts.js");
const tr = (s, ...a) => s.replace(/%(\d)/g, (_, i) => a[i - 1]);

// L'elenco di Win+Z deve dire in italiano ciò che il tasto fa davvero, non il nome grezzo dell'IPC
const cfg = [
    "set $mod Mod4",
    "bindsym $mod+Shift+e exec vela ipc call session logout",
    "bindsym $mod+Ctrl+Shift+r exec vela ipc call session reboot",
    "bindsym $mod+Ctrl+Shift+p exec vela ipc call session poweroff",
    "bindsym $mod+Tab exec vela ipc call layout next",
    "bindsym $mod+Shift+Tab exec vela ipc call layout prev",
    "bindsym $mod+k exec vela ipc call keyboard next",
    "bindsym $mod+x exec vela ipc call player stop",
].join("\n");
const rows = sh.build(sc.parse(cfg), [], () => "", tr).filter(r => r.kind === "bind");
const label = k => (rows.find(r => r.keys.join("+").toLowerCase() === k) || {}).label;
assert.strictEqual(label("super+shift+e"), "Esci dalla sessione");
assert.strictEqual(label("super+ctrl+shift+r"), "Riavvia");
assert.strictEqual(label("super+ctrl+shift+p"), "Spegni");
assert.strictEqual(label("super+tab"), "Layout successivo della finestra");
assert.strictEqual(label("super+shift+tab"), "Layout precedente della finestra");
assert.strictEqual(label("super+k"), "Layout di tastiera successivo");
assert.strictEqual(label("super+x"), "Ferma la riproduzione");
for (const r of rows) assert.ok(!/^Vela: /.test(r.label), "etichetta grezza: " + r.label);
console.log("ok shortcuts");
