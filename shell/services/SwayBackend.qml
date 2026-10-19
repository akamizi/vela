// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Backend Sway delle impostazioni del compositor (D-022): schermi, tastiera, touchpad, sfondo.
// Vela non modifica il config di Sway: genera ~/.config/vela/sway.d/vela.conf (da includere) e applica
// subito le modifiche con `swaymsg`. Ogni comando è un solo argomento a swaymsg (nessuna shell).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/swayconf.js" as SwayConf

Singleton {
    id: root

    readonly property bool active: Compositors.activeId === "sway"
    readonly property string home: Quickshell.env("HOME")
    readonly property string confDir: Config.userDir + "/sway.d"
    readonly property string confPath: confDir + "/vela.conf"
    readonly property string swayConfigPath: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/sway/config"

    property var outputs: []          // [{name, label, active, mode, modes, scale, transform, x, y}]
    property var inputs: []           // [{identifier, name, type}]
    readonly property bool hasTouchpad: inputs.some(function (i) { return i.type === "touchpad"; })
    // Acceso se almeno un touchpad non è del tutto disattivato ("disabled_on_external_mouse" conta come acceso).
    readonly property bool touchpadOn: inputs.some(function (i) { return i.type === "touchpad" && i.sendEvents !== "disabled"; })
    property string lastError: ""

    // --- lettura dello stato -----------------------------------------------------------
    function modeString(m) { return m.width + "x" + m.height + "@" + (m.refresh / 1000).toFixed(3) + "Hz"; }

    Process {
        id: outProc
        command: ["swaymsg", "-r", "-t", "get_outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.outputs = JSON.parse(text).map(function (o) {
                        var cur = o.current_mode;
                        return { name: o.name, label: (o.make + " " + o.model).trim(), active: o.active,
                                 mode: cur ? root.modeString(cur) : "", scale: o.scale, transform: o.transform,
                                 x: o.rect.x, y: o.rect.y,
                                 modes: (o.modes || []).map(root.modeString) };
                    });
                } catch (e) { root.outputs = []; }
            }
        }
    }
    Process {
        id: inProc
        command: ["swaymsg", "-r", "-t", "get_inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.inputs = JSON.parse(text).map(function (i) { return { identifier: i.identifier, name: i.name, type: i.type, sendEvents: i.libinput ? i.libinput.send_events : "" }; });
                } catch (e) { root.inputs = []; }
            }
        }
    }
    function refresh() {
        if (!active) return;
        if (!outProc.running) outProc.running = true;
        if (!inProc.running) inProc.running = true;
        swayCfg.reload();
    }
    function refreshInputs() { if (active && !inProc.running) inProc.running = true; }
    Component.onCompleted: refresh()

    function setTouchpad(on) {
        if (!active || !hasTouchpad) return;
        run("input type:touchpad events " + (on ? "enabled" : "disabled"));
        rereadInputs.restart();
    }
    Timer { id: rereadInputs; interval: 400; onTriggered: root.refreshInputs() }

    // --- esecuzione dei comandi (in coda, uno alla volta) ---------------------------------
    property var queue: []
    function run(cmd) { queue.push(cmd); pump(); }
    function pump() {
        if (runner.running || queue.length === 0) return;
        runner.command = ["swaymsg", "-r", queue.shift()];
        runner.running = true;
    }
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    JSON.parse(text).forEach(function (r) { if (!r.success) root.lastError = r.error || I18n.tr("comando rifiutato da Sway"); });
                } catch (e) {}
            }
        }
        onExited: root.pump()
    }

    // --- generazione dei comandi dalle impostazioni -----------------------------------------
    // Valori che finiscono in un comando: solo caratteri innocui (niente virgolette, $, ;, a capo).
    function safe(v) { return typeof v === "string" && /^[A-Za-z0-9_,:.()+\-\/ @#]*$/.test(v); }
    function num(v) { return typeof v === "number" && isFinite(v); }

    function outputCommand(name, p) {
        if (!/^[A-Za-z0-9_\-]+$/.test(name)) return "";
        var c = "output " + name;
        if (safe(p.mode) && p.mode) c += " mode " + p.mode;
        if (num(p.scale)) c += " scale " + p.scale;
        if (num(p.x) && num(p.y)) c += " pos " + Math.round(p.x) + " " + Math.round(p.y);
        if (["normal", "90", "180", "270"].indexOf(p.transform) >= 0) c += " transform " + p.transform;
        if (p.enabled === true) c += " enable"; else if (p.enabled === false) c += " disable";
        return c;
    }

    // Comandi senza a capo né caratteri di controllo (li scrive l'utente: sono suoi, ma una riga sola).
    function oneLine(v) { return typeof v === "string" && v.trim() !== "" && !/[\u0000-\u001f]/.test(v); }

    function bindCommand(b) {
        if (!b || typeof b.combo !== "string" || !/^[A-Za-z0-9_$+\-]+$/.test(b.combo)) return "";
        var combo = SwayConf.resolve(b.combo, userConfig.vars);
        if (typeof b.command !== "string" || b.command.trim() === "") return "unbindsym " + combo;
        return oneLine(b.command) ? "bindsym " + combo + " " + b.command.trim() : "";
    }
    function ruleCommand(rl) {
        if (!rl || !oneLine(rl.criteria) || !oneLine(rl.command)) return "";
        var c = rl.criteria.trim();
        if (c[0] !== "[") c = "[" + c + "]";
        return "for_window " + c + " " + rl.command.trim();
    }
    function execCommands() {
        return Config.sway.autostart.filter(oneLine).map(function (c) { return "exec " + c.trim(); });
    }

    // Comandi di tastiera, touchpad e sfondo (applicati subito e scritti nel file da includere).
    function inputWallpaperCommands() {
        var s = Config.sway, out = [];
        var k = s.input.keyboard, t = s.input.touchpad, w = s.wallpaper;
        function kb(key, v) { if (v !== null && v !== undefined && safe(String(v))) out.push("input type:keyboard " + key + " " + v); }
        kb("xkb_layout", k.layout); kb("xkb_variant", k.variant); kb("xkb_options", k.options);
        if (num(k.repeatDelay)) out.push("input type:keyboard repeat_delay " + Math.round(k.repeatDelay));
        if (num(k.repeatRate)) out.push("input type:keyboard repeat_rate " + Math.round(k.repeatRate));
        function tp(key, v) { if (v === "enabled" || v === "disabled") out.push("input type:touchpad " + key + " " + v); }
        tp("tap", t.tap); tp("natural_scroll", t.naturalScroll); tp("dwt", t.disableWhileTyping);
        if (num(t.accel)) out.push("input type:touchpad pointer_accel " + Math.max(-1, Math.min(1, t.accel)));
        // scorciatoie (le variabili del config, es. $mod, vanno risolte: swaymsg non le conosce)
        s.keybindings.forEach(function (b) {
            var cmd = bindCommand(b);
            if (cmd) out.push(cmd);
        });
        var g = s.gaps;
        if (num(g.inner)) out.push("gaps inner all set " + Math.round(g.inner));
        if (num(g.outer)) out.push("gaps outer all set " + Math.round(g.outer));
        if (num(g.border)) { out.push("default_border pixel " + Math.round(g.border)); out.push("default_floating_border pixel " + Math.round(g.border)); }
        if (["on", "off", "inverse_outer"].indexOf(g.smartGaps) >= 0) out.push("smart_gaps " + g.smartGaps);
        if (["on", "off", "no_gaps"].indexOf(g.smartBorders) >= 0) out.push("smart_borders " + g.smartBorders);
        s.rules.forEach(function (rl) {
            var cmd = ruleCommand(rl);
            if (cmd) out.push(cmd);
        });
        var modes = ["fill", "fit", "stretch", "center", "tile"];
        if (typeof w.path === "string" && w.path !== "" && safe(w.path))
            out.push('output * bg "' + w.path + '" ' + (modes.indexOf(w.mode) >= 0 ? w.mode : "fill"));
        else if (typeof w.color === "string" && /^#[0-9a-fA-F]{6}$/.test(w.color))
            out.push("output * bg " + w.color + " solid_color");
        return out;
    }

    function outputCommands() {
        var o = Config.sway.outputs, out = [];
        for (var name in o) { var c = outputCommand(name, o[name]); if (c) out.push(c); }
        return out;
    }

    // Applica ciò che è cambiato (tastiera, touchpad, sfondo) e riscrive il file da includere.
    property var applied: ({})
    property var appliedBinds: ({})
    property string lastConf: ""
    Timer { id: sync; interval: 400; onTriggered: root.syncNow() }
    Connections { target: Config; function onSwayChanged() { sync.restart(); } }

    function syncNow() {
        if (!active) return;
        var live = inputWallpaperCommands(), next = {};
        // Una scorciatoia di Vela tolta torna libera subito (quella originale del config torna al prossimo reload).
        var combos = {};
        Config.sway.keybindings.forEach(function (b) { var c = bindCommand(b); if (c) combos[c.split(" ")[1]] = true; });
        for (var old in appliedBinds) if (!combos[old]) run("unbindsym " + old);
        appliedBinds = combos;
        live.forEach(function (c) { next[c] = true; if (!applied[c]) run(c); });
        applied = next;
        var text = "# Generato da Vela (Impostazioni): non modificare a mano, le modifiche verrebbero perse.\n"
                 + live.concat(execCommands(), outputCommands()).join("\n") + "\n";
        if (text !== lastConf) { lastConf = text; confText = text; mkdir.running = true; }
    }

    property string confText: ""
    Process { id: mkdir; command: ["mkdir", "-p", root.confDir]; onExited: confFile.setText(root.confText) }
    FileView { id: confFile; path: root.confPath; atomicWrites: true; printErrors: false }

    // --- schermi, con conferma (si torna indietro se non si conferma entro 15 secondi) -----------
    property var pending: null        // {name, prev, next}
    property int countdown: 0

    function find(name) {
        for (var i = 0; i < outputs.length; i++) if (outputs[i].name === name) return outputs[i];
        return null;
    }
    function snapshot(o) { return { mode: o.mode, scale: o.scale, transform: o.transform, x: o.x, y: o.y, enabled: o.active }; }

    function setOutput(name, props) {
        var cur = find(name);
        if (!cur) return;
        if (pending && pending.name !== name) confirm();
        if (!pending) pending = { name: name, prev: snapshot(cur), next: snapshot(cur) };
        var next = {};
        for (var k in pending.next) next[k] = pending.next[k];
        for (var p in props) next[p] = props[p];
        pending = { name: name, prev: pending.prev, next: next };
        run(outputCommand(name, props));
        countdown = 15;
        tick.restart();
        reread.restart();
    }
    function confirm() {
        if (!pending) return;
        var n = pending.name, v = pending.next, map = {};
        map["outputs." + n + ".mode"] = v.mode;
        map["outputs." + n + ".scale"] = v.scale;
        map["outputs." + n + ".x"] = v.x;
        map["outputs." + n + ".y"] = v.y;
        map["outputs." + n + ".transform"] = v.transform;
        map["outputs." + n + ".enabled"] = v.enabled;
        Settings.setMany("sway", map);
        pending = null;
        tick.stop();
    }
    function revert() {
        if (!pending) return;
        run(outputCommand(pending.name, pending.prev));
        pending = null;
        tick.stop();
        reread.restart();
    }
    Timer {
        id: tick; interval: 1000; repeat: true
        onTriggered: { root.countdown--; if (root.countdown <= 0) root.revert(); }
    }
    Timer { id: reread; interval: 600; onTriggered: if (!outProc.running) outProc.running = true }

    // --- include nel config di Sway (solo su richiesta dell'utente, con copia di sicurezza) ----
    property string cfgText: ""     // contenuto del config di Sway, aggiornato a ogni lettura
    FileView {
        id: swayCfg
        path: root.swayConfigPath
        blockLoading: true; printErrors: false; atomicWrites: false; watchChanges: true
        onFileChanged: reload()
        onLoaded: root.cfgText = swayCfg.text()
        onLoadFailed: root.cfgText = ""
    }
    readonly property bool hasInclude: /^\s*include\s+\S*vela\/sway\.d\//m.test(cfgText)
    // Scorciatoie, avvii e regole del config di Sway (sola lettura): per elencarli e trovare i conflitti.
    readonly property var userConfig: SwayConf.parse(cfgText)

    // Se `combo` (nome di Vela o di Sway) è già assegnata: {source: "sway"|"vela", command} oppure null.
    function conflictFor(combo, ignoreVela) {
        var n = SwayConf.normalize(combo, userConfig.vars);
        var mine = Config.sway.keybindings;
        for (var i = 0; i < mine.length; i++)
            if (mine[i].combo !== ignoreVela && SwayConf.normalize(mine[i].combo, userConfig.vars) === n)
                return { source: "vela", command: mine[i].command || I18n.tr("(disattivata)") };
        for (var j = 0; j < userConfig.binds.length; j++)
            if (SwayConf.normalize(userConfig.binds[j].combo, userConfig.vars) === n)
                return { source: "sway", command: userConfig.binds[j].command };
        return null;
    }
    Process { id: backup; onExited: code => { if (code === 0) root.writeInclude(); else root.lastError = I18n.tr("copia di sicurezza non riuscita: config non modificato"); } }
    function addInclude() {
        if (hasInclude) return;
        backup.command = ["cp", "--no-clobber", swayConfigPath, swayConfigPath + ".bak-vela-include"];
        backup.running = true;
    }
    function writeInclude() {
        var t = cfgText;
        if (t.length > 0 && t[t.length - 1] !== "\n") t += "\n";
        t += "\n# Vela: impostazioni gestite da Vela (Impostazioni › Compositor)\ninclude ~/.config/vela/sway.d/*.conf\n";
        swayCfg.setText(t);
        lastConf = ""; syncNow();
    }
}
