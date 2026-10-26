// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Banco di prova per le librerie JS di shell/core (file `.pragma library` di QML).
// Uso: node tests/js/run.mjs        esegue tutti i tests/js/*.test.mjs, uno per processo.
// Nei test: import { load } from "./run.mjs"; const lib = load("shell/core/xxx.js");
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, "../..");

// Carica un file della shell: toglie `.pragma …`, risolve `.import "x.js" as Nome` come globale `Nome`,
// lo esegue in un contesto isolato e restituisce l'oggetto con funzioni e `var` dichiarate.
export function load(rel, globals = {}) {
    const file = path.join(root, rel);
    const ctx = { ...globals };
    let code = fs.readFileSync(file, "utf8");
    code = code.replace(/^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/gm, (_, f, name) => {
        ctx[name] = load(path.join(path.dirname(rel), f));
        return "";
    });
    code = code.replace(/^\.pragma\s.*$/gm, "");
    vm.createContext(ctx);
    vm.runInContext(code, ctx, { filename: file });
    return ctx;
}

// Eseguito come programma: lancia i test.
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    const tests = fs.readdirSync(here).filter(f => f.endsWith(".test.mjs")).sort();
    let failed = 0;
    for (const t of tests) {
        const r = spawnSync(process.execPath, [path.join(here, t)], { stdio: "inherit" });
        if (r.status !== 0) { failed++; console.error("FAIL " + t); }
    }
    console.log(failed === 0 ? `tutti ok (${tests.length} file)` : `${failed} file falliti`);
    process.exit(failed === 0 ? 0 : 1);
}
