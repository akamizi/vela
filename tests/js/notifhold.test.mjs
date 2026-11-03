// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load, plain } from "./run.mjs";

const h = load("shell/core/notifhold.js");

// Sotto il limite: tutto resta, in ordine di arrivo
let r = plain(h.hold([], 1, 3));
assert.deepStrictEqual(r, { ids: [1], dropped: [] });
r = plain(h.hold(r.ids, 2, 3)); r = plain(h.hold(r.ids, 3, 3));
assert.deepStrictEqual(r, { ids: [1, 2, 3], dropped: [] });
// Oltre il limite: si scarta la più vecchia (una per volta, o più se serve)
r = plain(h.hold(r.ids, 4, 3));
assert.deepStrictEqual(r, { ids: [2, 3, 4], dropped: [1] });
assert.deepStrictEqual(plain(h.hold([1, 2, 3, 4, 5], 6, 3)), { ids: [4, 5, 6], dropped: [1, 2, 3] });
// Lo stesso id due volte non si conta due volte e passa in fondo
assert.deepStrictEqual(plain(h.hold([1, 2, 3], 1, 3)), { ids: [2, 3, 1], dropped: [] });
// Limiti strani: almeno una notifica resta
assert.deepStrictEqual(plain(h.hold([1, 2], 3, 0)), { ids: [3], dropped: [1, 2] });
assert.deepStrictEqual(plain(h.hold([1], 2, "x")), { ids: [2], dropped: [1] });
assert.deepStrictEqual(plain(h.hold([1, 2, 3], 4, 2.9)), { ids: [3, 4], dropped: [1, 2] });
// La coda in ingresso non si modifica
const src = [1, 2, 3]; h.hold(src, 4, 2); assert.deepStrictEqual(src, [1, 2, 3]);
assert.strictEqual(h.isHeld([1, 2], 2), true);
assert.strictEqual(h.isHeld([1, 2], 3), false);
console.log("notifhold: ok");
