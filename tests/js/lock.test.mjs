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

// Blocco prima della sospensione (coperchio, tasto di accensione, qualunque sospensione): swayidle tiene l'inibitore di elogind
// finché il comando di blocco non è finito. Qui un finto swayidle registra gli argomenti ricevuti.
const rec = path.join(dir, "swayidle-args.json");
mk("swayidle", `printf '%s\\n' "$@" > ${rec}`);
const lockLog = path.join(dir, "lock-args.txt");
const fakeLock = mk("fakelock", `printf '%s\\n' "$@" > ${lockLog}`);
const sl = lock.sleepLockCommand([fakeLock, "a b", "it's"]);
const r = spawnSync("/bin/sh", sl.slice(1), { env: { PATH: dir + ":/usr/bin:/bin" }, encoding: "utf8", timeout: 10000 });
assert.strictEqual(r.status, 0, r.stderr);
const got = fs.readFileSync(rec, "utf8").split("\n").slice(0, -1);
assert.deepStrictEqual(got.slice(0, 2), ["-w", "before-sleep"]);
// il comando passato a swayidle (che lo esegue con sh -c) deve ridare gli argomenti identici, anche con spazi e apici
const r2 = spawnSync("/bin/sh", ["-c", got[2]], { env: { PATH: "/usr/bin:/bin" }, encoding: "utf8", timeout: 10000 });
assert.strictEqual(r2.status, 0, r2.stderr);
assert.deepStrictEqual(fs.readFileSync(lockLog, "utf8").split("\n").slice(0, -1), ["a b", "it's"]);
// senza swayidle installato non è un errore
const empty = fs.mkdtempSync(path.join(os.tmpdir(), "vela-empty-"));
assert.strictEqual(spawnSync("/bin/sh", sl.slice(1), { env: { PATH: empty }, timeout: 10000 }).status, 0);
fs.rmSync(empty, { recursive: true, force: true });

fs.rmSync(dir, { recursive: true, force: true });
console.log("ok lock");
