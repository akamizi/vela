// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load, plain } from "./run.mjs";

const rec = load("shell/core/reclib.js");
const eq = (a, b) => assert.deepStrictEqual(plain(a), b);

assert.strictEqual(rec.fileName(new Date(2026, 9, 26, 14, 5, 9)), "rec-20261026-140509.mp4");
assert.strictEqual(rec.fileName(new Date(2026, 0, 2, 3, 4, 5)), "rec-20260102-030405.mp4");

const both = "VAProfileH264Main : VAEntrypointEncSlice\nVAProfileNone : VAEntrypointVideoProc\n";
assert.strictEqual(rec.vaapiOk(both), true);
assert.strictEqual(rec.vaapiOk("VAProfileH264Main : VAEntrypointEncSlice\n"), false);
assert.strictEqual(rec.vaapiOk("VAProfileNone : VAEntrypointVideoProc\nVAProfileH264Main : VAEntrypointVLD\n"), false);
assert.strictEqual(rec.vaapiOk(""), false);

eq(rec.recorderArgs("area", "10,20 300x200", "software", "/v/a.mp4", "/dev/dri/renderD128"),
   ["-g", "10,20 300x200", "-c", "libx264", "-p", "preset=veryfast", "-f", "/v/a.mp4"]);
eq(rec.recorderArgs("screen", "", "vaapi", "/v/a.mp4", "/dev/dri/renderD128"),
   ["-c", "h264_vaapi", "-d", "/dev/dri/renderD128", "-f", "/v/a.mp4"]);
// con lo schermo intero la geometria non si usa, anche se passata
eq(rec.recorderArgs("screen", "1,1 2x2", "software", "/v/a.mp4", "/r"), ["-c", "libx264", "-p", "preset=veryfast", "-f", "/v/a.mp4"]);
// l'area senza geometria (slurp annullato) non produce argomenti: lo si evita prima, ma la funzione non deve inventarne
eq(rec.recorderArgs("area", "", "software", "/v/a.mp4", "/r"), []);
console.log("ok reclib");
