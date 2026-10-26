// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load } from "./run.mjs";

const swayconf = load("shell/core/swayconf.js");
assert.strictEqual(swayconf.normalize("$mod+Shift+e", { "$mod": "Mod4" }), "shift+super+e");
console.log("ok smoke");
