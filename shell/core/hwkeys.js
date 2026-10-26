// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Tasti in più (multimediali, preferiti, ritaglio del ThinkPad T14…): quali esistono sul PC, letti dalle capacità dei dispositivi
// di input (/proc/bus/input/devices, senza privilegi), e le scorciatoie predefinite da associare solo a quelli che ci sono.
.pragma library

// Codici evdev dei tasti
var KEY_NEXTSONG = 163, KEY_PLAYPAUSE = 164, KEY_PREVIOUSSONG = 165, KEY_FAVORITES = 364, KEY_SELECTIVE_SCREENSHOT = 634;

// Unione delle maschere `B: KEY=` di tutti i dispositivi: parole da 64 bit in esadecimale, la più alta per prima.
// Risultato: {codice: true}. Testo vuoto o illeggibile → {}.
function keyCodes(devicesText) {
    var out = {};
    String(devicesText).split("\n").forEach(function (line) {
        var m = /^B:\s*KEY=([0-9a-fA-F ]+)$/.exec(line.trim());
        if (!m) return;
        var words = m[1].trim().split(/\s+/);
        for (var w = 0; w < words.length; w++) {
            var word = words[words.length - 1 - w];              // w = 0: la parola meno significativa
            for (var d = 0; d < word.length; d++) {
                var digit = parseInt(word.charAt(word.length - 1 - d), 16);
                for (var b = 0; b < 4; b++) if (digit & (1 << b)) out[w * 64 + d * 4 + b] = true;
            }
        }
    });
    return out;
}

// Scorciatoie predefinite per i tasti presenti: [{combo, command, description, code?}] (code: la combinazione usa un keycode, `bindcode`).
// `tr`: traduzione dei testi (facoltativa). Il tasto Copilot (Win+Maiusc+F23, keycode 201) manda un tasto normale e non si
// riconosce: si associa sempre (Sway lo vede come XF86Assistant con Win+Maiusc, per questo si usa il keycode).
function hardwareBindings(codes, translate) {
    var tr = translate || function (s) { return s; };   // le chiamate tr("…") sono quelle lette da scripts/i18n-extract
    var out = [];
    function add(code, combo, command, description) { if (code === 0 || codes[code]) out.push({ combo: combo, command: command, description: description }); }
    add(KEY_PLAYPAUSE, "XF86AudioPlay", "exec vela ipc call media playPause", tr("Riproduci / pausa"));
    add(KEY_NEXTSONG, "XF86AudioNext", "exec vela ipc call media next", tr("Brano successivo"));
    add(KEY_PREVIOUSSONG, "XF86AudioPrev", "exec vela ipc call media previous", tr("Brano precedente"));
    add(KEY_FAVORITES, "XF86Favorites", "exec vela files", tr("Gestore di file"));
    add(KEY_SELECTIVE_SCREENSHOT, "XF86SelectiveScreenshot", "exec sh -c 'grim -g \"$(slurp)\" - | swappy -f -'", tr("Screenshot di un'area"));
    add(KEY_SELECTIVE_SCREENSHOT, "$mod+XF86SelectiveScreenshot", "exec vela ipc call recorder toggle area", tr("Registra un'area"));
    add(0, "$mod+Shift+201", "exec vela files", tr("Tasto Copilot"));
    out[out.length - 1].code = true;
    return out;
}
