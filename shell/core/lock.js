// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
.pragma library

// Comando che blocca lo schermo e torna solo a blocco avvenuto (il comando deve staccarsi dopo aver bloccato, come `swaylock -f`):
// esce 0 se il blocco è riuscito o ce n'è già uno dello stesso utente, altrimenti 1. Chi sospende lo fa solo con 0.
// Il comando è un array: nessuna shell sulla stringa. pgrep -x confronta il nome troncato a 15 caratteri.
function waitLockArgv(cmd) {
    var name = String(cmd[0]).split("/").pop().slice(0, 15);
    return ["sh", "-c", 'name=$1; shift; pgrep -u "$(id -u)" -x "$name" >/dev/null 2>&1 && exit 0; "$@" || exit 1', "sh", name].concat(cmd);
}

// Colori e carattere del tema di Vela per swaylock, solo se il comando è quello predefinito (`swaylock -f`): chi lo ha
// personalizzato non viene toccato. `theme`: {background, surface, foreground, accent, error} come «#rrggbb» e font facoltativo.
function themedCommand(cmd, theme) {
    if (!Array.isArray(cmd) || cmd.length !== 2 || String(cmd[0]).split("/").pop() !== "swaylock" || cmd[1] !== "-f") return cmd;
    var c = {};
    var keys = ["background", "surface", "foreground", "accent", "error"];
    for (var i = 0; i < keys.length; i++) {
        var v = theme && theme[keys[i]];
        if (typeof v !== "string" || !/^#[0-9a-fA-F]{6}$/.test(v)) return cmd;
        c[keys[i]] = v.slice(1);
    }
    var out = cmd.concat(["--color", c.background, "--separator-color", c.background, "--line-uses-ring"]);
    ["", "-clear", "-ver", "-wrong"].forEach(function (s) { out.push("--inside" + s + "-color", c.surface); });
    out.push("--ring-color", c.accent, "--ring-clear-color", c.accent, "--ring-ver-color", c.accent, "--ring-wrong-color", c.error);
    out.push("--text-color", c.foreground, "--text-clear-color", c.foreground, "--text-ver-color", c.foreground, "--text-wrong-color", c.error);
    out.push("--key-hl-color", c.accent, "--bs-hl-color", c.error);
    if (theme.font && typeof theme.font === "string") out.push("--font", theme.font);
    return out;
}
