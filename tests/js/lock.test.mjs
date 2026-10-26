// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { load } from "./run.mjs";

const lock = load("shell/core/lock.js");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "vela-lock-"));
const mk = (name, body) => { const f = path.join(dir, name); fs.writeFileSync(f, "#!/bin/sh\n" + body + "\n", { mode: 0o755 }); return f; };
const run = cmd => spawnSync(lock.waitLockArgv(cmd)[0], lock.waitLockArgv(cmd).slice(1), { encoding: "utf8", timeout: 10000 }).status;

// 1. il blocco riesce: si può sospendere
assert.strictEqual(run([mk("blocca-ok", "exit 0")]), 0);
// 2. il blocco fallisce o il comando non esiste: NON si sospende
assert.notStrictEqual(run([mk("blocca-ko", "exit 3")]), 0);
assert.notStrictEqual(run([path.join(dir, "non-esiste")]), 0);
// 3. un blocco dello stesso utente è già attivo: non se ne lancia un altro e si può sospendere
const name = "velalock" + process.pid;
const fake = path.join(dir, name);
fs.symlinkSync(fs.realpathSync("/bin/sleep"), fake);
const bg = spawn(fake, ["30"], { stdio: "ignore" });
await new Promise(r => setTimeout(r, 300));
try { assert.strictEqual(run([fake, "--non-valida"]), 0); }   // se fosse lanciato, sleep fallirebbe
finally { bg.kill(); }
// 4. con il blocco ormai terminato, lo stesso comando viene lanciato davvero (e qui fallisce)
await new Promise(r => setTimeout(r, 300));
assert.notStrictEqual(run([fake, "--non-valida"]), 0);

// Colori del tema per swaylock: solo per il comando predefinito, senza «#»
const th = { background: "#101820", surface: "#18222d", foreground: "#e6edf3", accent: "#58a6ff", error: "#ff7b72", font: "JetBrains Mono" };
const a = lock.themedCommand(["swaylock", "-f"], th);
assert.deepStrictEqual(a.slice(0, 2), ["swaylock", "-f"]);
assert.strictEqual(a[a.indexOf("--color") + 1], "101820");
assert.strictEqual(a[a.indexOf("--ring-color") + 1], "58a6ff");
assert.strictEqual(a[a.indexOf("--ring-wrong-color") + 1], "ff7b72");
assert.strictEqual(a[a.indexOf("--font") + 1], "JetBrains Mono");
assert.ok(a.every(x => !String(x).startsWith("#")));
assert.deepStrictEqual(lock.themedCommand(["swaylock", "-f", "-c", "000000"], th), ["swaylock", "-f", "-c", "000000"]);   // già personalizzato
assert.deepStrictEqual(lock.themedCommand(["gtklock"], th), ["gtklock"]);
assert.deepStrictEqual(lock.themedCommand(["swaylock", "-f"], { background: "rosso" }), ["swaylock", "-f"]);                // tema non valido

fs.rmSync(dir, { recursive: true, force: true });
console.log("ok lock");
