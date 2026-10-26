// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load } from "./run.mjs";

const n = load("shell/core/names.js");

// Nomi di stampanti, job e servizi: parole semplici, mai interpretabili come opzione di un comando
for (const ok of ["HP_LaserJet", "Canon.MG3600", "Stampante-2", "HP-123", "a", "_x"]) assert.strictEqual(n.validName(ok), true, ok);
for (const bad of ["-a", "--help", "-x", "", "a b", "a;b", "a/b", "a\nb", 7, null, undefined]) assert.strictEqual(n.validName(bad), false, String(bad));
console.log("ok names");
