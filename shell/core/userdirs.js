// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Cartelle utente XDG (~/.config/user-dirs.dirs): il nome cambia con la lingua (Musica, Music…), la chiave no.
.pragma library

// Valore di `key` (es. "XDG_MUSIC_DIR") con $HOME espanso; "" se manca o se vale la cartella personale
// (è così che XDG dice «non impostata»).
function userDir(text, home, key) {
    var lines = String(text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var m = /^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/.exec(lines[i]);
        if (!m || m[1] !== key) continue;
        var v = m[2].replace(/^\$HOME(?=\/|$)/, home).replace(/\/+$/, "");
        return v === home || v === "" ? "" : v;
    }
    return "";
}
