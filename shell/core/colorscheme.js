// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
.pragma library

// Luminanza relativa WCAG di un colore «#rgb», «#rrggbb» o «#rrggbbaa» (l'alfa si ignora); -1 se il testo non è un colore.
function luminance(hex) {
    var m = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(String(hex));
    if (!m) return -1;
    var h = m[1];
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var c = [0, 2, 4].map(function (i) {
        var v = parseInt(h.slice(i, i + 2), 16) / 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

// Valore di `org.gnome.desktop.interface color-scheme` che corrisponde al tema (D-063): scuro se lo sfondo è più scuro del
// testo. Se uno dei due colori non è valido, null: meglio non toccare niente che indovinare.
function schemeFor(background, foreground) {
    var b = luminance(background), f = luminance(foreground);
    if (b < 0 || f < 0 || b === f) return null;
    return b < f ? "prefer-dark" : "prefer-light";
}

// `gsettings get` stampa il valore tra apici ('prefer-dark'): lo si toglie per il confronto.
function cleanValue(out) { return String(out).trim().replace(/^'(.*)'$/, "$1"); }
