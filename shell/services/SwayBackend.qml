// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Backend Sway delle impostazioni del compositor (D-022): schermi, tastiera, touchpad, sfondo.
// Vela non modifica il config di Sway: genera ~/.config/vela/sway.d/vela.conf (da includere) e applica
// subito le modifiche con `swaymsg`. Ogni comando è un solo argomento a swaymsg (nessuna shell).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

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
                    root.inputs = JSON.parse(text).map(function (i) { return { identifier: i.identifier, name: i.name, type: i.type }; });
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
    Component.onCompleted: refresh()

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
                    JSON.parse(text).forEach(function (r) { if (!r.success) root.lastError = r.error || "comando rifiutato da Sway"; });
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
    property string lastConf: ""
    Timer { id: sync; interval: 400; onTriggered: root.syncNow() }
    Connections { target: Config; function onSwayChanged() { sync.restart(); } }

    function syncNow() {
        if (!active) return;
        var live = inputWallpaperCommands(), next = {};
        live.forEach(function (c) { next[c] = true; if (!applied[c]) run(c); });
        applied = next;
        var text = "# Generato da Vela (Impostazioni): non modificare a mano, le modifiche verrebbero perse.\n"
                 + live.concat(outputCommands()).join("\n") + "\n";
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
    FileView { id: swayCfg; path: root.swayConfigPath; blockLoading: true; printErrors: false; atomicWrites: false }
    readonly property bool hasInclude: {
        var t = ""; try { t = swayCfg.text(); } catch (e) {}
        return /^\s*include\s+\S*vela\/sway\.d\//m.test(t);
    }
    Process { id: backup; onExited: code => { if (code === 0) root.writeInclude(); else root.lastError = "copia di sicurezza non riuscita: config non modificato"; } }
    function addInclude() {
        if (hasInclude) return;
        backup.command = ["cp", "--no-clobber", swayConfigPath, swayConfigPath + ".bak-vela-include"];
        backup.running = true;
    }
    function writeInclude() {
        var t = swayCfg.text();
        if (t.length > 0 && t[t.length - 1] !== "\n") t += "\n";
        t += "\n# Vela: impostazioni gestite da Vela (Impostazioni › Compositor)\ninclude ~/.config/vela/sway.d/*.conf\n";
        swayCfg.setText(t);
        lastConf = ""; syncNow();
        refreshSoon.restart();
    }
    Timer { id: refreshSoon; interval: 800; onTriggered: swayCfg.reload() }
}
