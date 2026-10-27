// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Contrasto WCAG AA (4,5:1) dei colori di testo del tema predefinito (D-060): su sfondo, superficie
// e riga selezionata (colore del testo con l'opacità `states.selected` sopra la superficie).
import assert from "node:assert";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const file = path.join(path.dirname(fileURLToPath(import.meta.url)), "../../config/defaults/theme.jsonc");
const theme = JSON.parse(fs.readFileSync(file, "utf8").replace(/^\s*\/\/.*$/gm, ""));
const rgb = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const lum = c => {
    const [r, g, b] = c.map(x => { x /= 255; return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4; });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a, b) => { const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x); return (hi + 0.05) / (lo + 0.05); };
const mix = (bg, fg, a) => bg.map((v, i) => Math.round(v * (1 - a) + fg[i] * a));

const c = Object.fromEntries(Object.entries(theme.colors).map(([k, v]) => [k, rgb(v)]));
const selected = mix(c.surface, c.foreground, theme.states.selected);
const onBg = { sfondo: c.background, superficie: c.surface, "riga selezionata": selected };

// Testo che compare anche sulle righe selezionate; `dim` solo su sfondo e superficie (suggerimenti, segnaposto).
const text = { foreground: Object.keys(onBg), muted: Object.keys(onBg), accent: Object.keys(onBg),
               warning: Object.keys(onBg), error: Object.keys(onBg), dim: ["sfondo", "superficie"] };
for (const [name, where] of Object.entries(text))
    for (const w of where)
        assert.ok(ratio(c[name], onBg[w]) >= 4.5, `${name} su ${w}: ${ratio(c[name], onBg[w]).toFixed(2)} < 4,5`);
