// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load, plain } from "./run.mjs";

const hw = load("shell/core/hwkeys.js");
const eq = (a, b) => assert.deepStrictEqual(plain(a), b);

// Costruisce la maschera `B: KEY=` come la scrive il kernel: parole da 64 bit in esadecimale, la più alta per prima, senza zeri iniziali.
function keyMask(codes) {
    const max = Math.max(...codes);
    const words = new Array(Math.floor(max / 64) + 1).fill(0n);
    for (const c of codes) words[Math.floor(c / 64)] |= 1n << BigInt(c % 64);
    return words.reverse().map((w, i) => i === 0 ? w.toString(16) : w.toString(16).padStart(16, "0")).join(" ");
}
const dev = (name, codes) => `I: Bus=0019 Vendor=17aa Product=5054 Version=4101\nN: Name="${name}"\nB: PROP=0\nB: EV=3\nB: KEY=${keyMask(codes)}\nB: REL=0\n\n`;

// lettura delle maschere
const text = dev("kbd uno", [30, 164, 163]) + dev("hotkeys", [634, 364, 165]);
const codes = plain(hw.keyCodes(text));
for (const c of [30, 163, 164, 165, 364, 634]) assert.ok(codes[c], "manca " + c);
assert.ok(!codes[31]);
assert.ok(!codes[200]);
eq(hw.keyCodes(""), {});
eq(hw.keyCodes("B: KEY=zzzz qq\nspazzatura"), {});
eq(hw.keyCodes("N: Name=\"x\"\nB: EV=3\n"), {});

// senza tasti in più resta solo il tasto Copilot (F23 non si può rilevare)
const none = plain(hw.hardwareBindings({}));
eq(none.map(b => b.combo), ["$mod+Shift+201"]);
assert.strictEqual(none[0].code, true);
assert.strictEqual(none[0].command, "exec vela files");

// con i tasti: combinazioni e comandi
const all = plain(hw.hardwareBindings({ 163: true, 164: true, 165: true, 364: true, 634: true }, s => s));
const by = Object.fromEntries(all.map(b => [b.combo, b.command]));
assert.strictEqual(by["XF86AudioPlay"], "exec vela ipc call media playPause");
assert.strictEqual(by["XF86AudioNext"], "exec vela ipc call media next");
assert.strictEqual(by["XF86AudioPrev"], "exec vela ipc call media previous");
assert.strictEqual(by["XF86Favorites"], "exec vela files");
assert.strictEqual(by["XF86SelectiveScreenshot"], `exec sh -c 'grim -g "$(slurp)" - | swappy -f -'`);
assert.strictEqual(by["$mod+XF86SelectiveScreenshot"], "exec vela ipc call recorder toggle area");
assert.strictEqual(by["$mod+Shift+201"], "exec vela files");
assert.strictEqual(all.length, 7);
assert.ok(all.every(b => typeof b.description === "string" && b.description !== ""));
// solo il tasto ritaglio: niente tasti multimediali
eq(plain(hw.hardwareBindings({ 634: true })).map(b => b.combo), ["XF86SelectiveScreenshot", "$mod+XF86SelectiveScreenshot", "$mod+Shift+201"]);
console.log("ok hwkeys");
