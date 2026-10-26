// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Backend Sway delle impostazioni del compositor (D-022): schermi, tastiera, touchpad, sfondo.
// Vela non modifica il config di Sway: genera ~/.config/vela/sway.d/vela.conf (da includere) e applica
// subito le modifiche con `swaymsg`. Ogni comando è un solo argomento a swaymsg (nessuna shell).
// Sotto labwc (sessione «Vela (labwc)») il backend gestisce solo gli schermi, con `wlr-randr`: stessa interfaccia, stessa conferma di
// 15 secondi; le scelte confermate si salvano in ~/.config/vela/labwc.d/vela-outputs.sh, che l'autostart della sessione esegue.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/swayconf.js" as SwayConf

Singleton {
    id: root

    readonly property bool active: Compositors.activeId === "sway"
    readonly property bool labwc: Compositors.activeId === "labwc"
    readonly property string home: Quickshell.env("HOME")
    readonly property string confDir: Config.userDir + "/sway.d"
    readonly property string confPath: confDir + "/vela.conf"
    // Config di Sway: quello che il compositor ha caricato davvero (la sessione Vela usa `sway -c /usr/share/vela/sway/config`),
    // altrimenti quello dell'utente. Elenco scorciatoie e conflitti devono leggere lo stesso file che Sway esegue.
    readonly property string defaultConfigPath: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/sway/config"
    property string loadedConfig: ""
    readonly property string swayConfigPath: loadedConfig !== "" ? loadedConfig : defaultConfigPath
    Process {
        id: verProc
        command: ["swaymsg", "-r", "-t", "get_version"]
        stdout: StdioCollector { onStreamFinished: root.loadedConfig = SwayConf.loadedConfigPath(text) }
    }

    property var outputs: []          // [{name, label, active, mode, modes, scale, transform, x, y}]
    property var inputs: []           // [{identifier, name, type}]
    readonly property bool hasTouchpad: inputs.some(function (i) { return i.type === "touchpad"; })
    // Acceso se almeno un touchpad non è del tutto disattivato ("disabled_on_external_mouse" conta come acceso).
    readonly property bool touchpadOn: inputs.some(function (i) { return i.type === "touchpad" && i.sendEvents !== "disabled"; })
    property string lastError: ""

    // Layout di tastiera: si considera la prima tastiera con più di un layout configurato (D-037).
    readonly property var keyboard: {
        for (var k = 0; k < inputs.length; k++)
            if (inputs[k].type === "keyboard" && inputs[k].layouts.length > 1) return inputs[k];
        return null;
    }
    readonly property int layoutCount: keyboard ? keyboard.layouts.length : 0
    readonly property string layoutName: keyboard ? (keyboard.layouts[keyboard.layoutIndex] || "") : ""
    // Sigla breve dal nome del layout ("Italian" → IT, "English (US)" → US).
    function layoutCode(name) {
        var m = /\(([^)]+)\)/.exec(name);
        if (m) return m[1].slice(0, 3).toUpperCase();
        var known = { "Italian": "IT", "English": "EN", "German": "DE", "French": "FR", "Spanish": "ES", "Portuguese": "PT",
                      "Russian": "RU", "Dutch": "NL", "Swedish": "SE", "Norwegian": "NO", "Danish": "DK", "Finnish": "FI",
                      "Polish": "PL", "Czech": "CZ", "Greek": "GR", "Turkish": "TR", "Japanese": "JP", "Korean": "KR", "Swiss": "CH" };
        var first = name.split(" ")[0];
        return known[first] || first.slice(0, 2).toUpperCase();
    }
    function switchLayout(direction) {
        if (!active || layoutCount < 2) return;
        run("input type:keyboard xkb_switch_layout " + (direction < 0 ? "prev" : "next"));
        rereadInputs.restart();
    }
    // Con il demone dati (D-039) gli input arrivano da lì in tempo reale (abbonamento agli eventi di Sway fatto dal demone):
    // niente `swaymsg` periodico né abbonamento qui. Se il demone manca o non è fresco, resta il controllo di prima.
    readonly property bool daemonInputs: Daemon.ready("sway")
    Connections {
        target: Daemon
        function onModuleState(module) { if (module === "sway") root.applyDaemonInputs(); }
    }
    function applyDaemonInputs() {
        var st = Daemon.states.sway;
        if (!st || !Array.isArray(st.inputs)) return;
        inputs = st.inputs.map(function (i) {
            return { identifier: String(i.id || ""), name: String(i.name || ""), type: String(i.type || ""),
                     sendEvents: String(i.send_events || ""),
                     layouts: Array.isArray(i.layouts) ? i.layouts.map(String) : [], layoutIndex: Number(i.layout_index) || 0 };
        });
    }

    // Sway avvisa a ogni cambio di layout: ci si abbona solo se serve (più di un layout).
    Process {
        command: ["swaymsg", "-m", "-t", "subscribe", "[\"input\"]"]
        running: root.active && root.layoutCount > 1 && !root.daemonInputs
        stdout: SplitParser { onRead: root.refreshInputs() }
    }

    // --- lettura dello stato -----------------------------------------------------------
    function modeString(m) { return m.width + "x" + m.height + "@" + (m.refresh / 1000).toFixed(3) + "Hz"; }

    // Senza una frequenza valida (schermi virtuali, sessioni annidate) si indica solo la risoluzione: wlr-randr rifiuta «@0.000Hz».
    function randrMode(m) { return m.width + "x" + m.height + (m.refresh > 0 ? "@" + m.refresh.toFixed(3) + "Hz" : ""); }
    // Schermi da `wlr-randr --json`, nella stessa forma di quelli di Sway.
    function parseRandr(text) {
        return JSON.parse(text).map(function (o) {
            var cur = null;
            (o.modes || []).forEach(function (m) { if (m.current) cur = m; });
            var sc = o.scale > 0 ? o.scale : 1, tr = o.transform || "normal";
            var w = cur ? cur.width : 0, h = cur ? cur.height : 0;
            if (/90|270/.test(tr)) { var t = w; w = h; h = t; }
            return { name: o.name, label: ((o.make || "") + " " + (o.model || "")).trim(), active: o.enabled === true,
                     mode: cur ? root.randrMode(cur) : "", scale: sc, transform: tr,
                     x: o.position ? o.position.x : 0, y: o.position ? o.position.y : 0, w: Math.round(w / sc), h: Math.round(h / sc),
                     modes: (o.modes || []).map(root.randrMode) };
        });
    }
    Process {
        id: outProc
        command: root.labwc ? ["wlr-randr", "--json"] : ["swaymsg", "-r", "-t", "get_outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (root.labwc) { root.outputs = root.parseRandr(text); return; }
                    root.outputs = JSON.parse(text).map(function (o) {
                        var cur = o.current_mode;
                        return { name: o.name, label: (o.make + " " + o.model).trim(), active: o.active,
                                 mode: cur ? root.modeString(cur) : "", scale: o.scale, transform: o.transform,
                                 x: o.rect.x, y: o.rect.y, w: o.rect.width, h: o.rect.height,
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
                    root.inputs = JSON.parse(text).map(function (i) { return { identifier: i.identifier, name: i.name, type: i.type, sendEvents: i.libinput ? i.libinput.send_events : "", layouts: i.xkb_layout_names || [], layoutIndex: i.xkb_active_layout_index || 0 }; });
                } catch (e) { root.inputs = []; }
            }
        }
    }
    function refresh() {
        if (!active && !labwc) return;
        if (!outProc.running) outProc.running = true;
        if (labwc) return;
        if (loadedConfig === "" && !verProc.running) verProc.running = true;
        if (!inProc.running && !daemonInputs) inProc.running = true;
        swayCfg.reload();
    }
    function refreshInputs() { if (active && !daemonInputs && !inProc.running) inProc.running = true; }
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
        var cmd = queue.shift();
        runner.command = Array.isArray(cmd) ? cmd : ["swaymsg", "-r", cmd];     // lista = comando intero (wlr-randr)
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
        onExited: code => { if (root.labwc && code !== 0) root.lastError = I18n.tr("comando rifiutato da wlr-randr"); root.pump(); }
    }

    // --- generazione dei comandi dalle impostazioni -----------------------------------------
    // Valori che finiscono in un comando: solo caratteri innocui (vedi swayconf.js: niente virgole, virgolette, $, ;, a capo).
    function safe(v) { return SwayConf.safe(v); }
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

    // Lo stesso per labwc: argomenti di `wlr-randr` (lista vuota se non c'è niente da fare).
    function randrArgs(name, p) {
        if (!/^[A-Za-z0-9_\-]+$/.test(name)) return [];
        var a = ["wlr-randr", "--output", name];
        if (safe(p.mode) && p.mode) a.push("--mode", p.mode);
        if (num(p.scale)) a.push("--scale", String(p.scale));
        if (num(p.x) && num(p.y)) a.push("--pos", Math.round(p.x) + "," + Math.round(p.y));
        if (["normal", "90", "180", "270"].indexOf(p.transform) >= 0) a.push("--transform", p.transform);
        if (p.enabled === true) a.push("--on"); else if (p.enabled === false) a.push("--off");
        return a.length > 3 ? a : [];
    }
    function outCmd(name, p) { return labwc ? randrArgs(name, p) : outputCommand(name, p); }

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

    // Tasti in più del PC (HardwareKeys), senza `$mod` (nel config della sessione Vela la variabile non è nota a swaymsg) e
    // solo se la combinazione non è già assegnata dall'utente (config di Sway o scorciatoie di Vela): la riga dell'utente vince.
    function hwCombo(b) { return b.combo.replace(/\$mod/g, "Mod4"); }
    readonly property var hardwareShown: HardwareKeys.bindings.filter(function (b) {
        return conflictFor(hwCombo(b), "") === null;
    }).map(function (b) { return { combo: hwCombo(b), command: b.command, description: b.description, code: b.code === true }; })
    function hardwareCommands() {
        return hardwareShown.map(function (b) {
            // i tasti multimediali valgono anche a schermo bloccato, come gli altri tasti di volume
            return (b.code ? "bindcode " : "bindsym ") + (/^XF86Audio/.test(b.combo) ? "--locked " : "") + b.combo + " " + b.command;
        });
    }
    // Comando che scioglie il tasto in più (le opzioni, come --locked, devono essere le stesse dell'associazione).
    function hwUnbind(b) { return (b.code ? "unbindcode " : "unbindsym ") + (/^XF86Audio/.test(b.combo) ? "--locked " : "") + b.combo; }
    Connections { target: HardwareKeys; function onBindingsChanged() { sync.restart(); } }

    // Comandi di tastiera, touchpad e sfondo (applicati subito e scritti nel file da includere).
    function inputWallpaperCommands() {
        var s = Config.sway, out = [];
        var k = s.input.keyboard, t = s.input.touchpad, w = s.wallpaper;
        function kb(key, v) { if (v !== null && v !== undefined && SwayConf.safeList(String(v))) out.push("input type:keyboard " + key + " " + v); }
        kb("xkb_layout", k.layout); kb("xkb_variant", k.variant); kb("xkb_options", k.options);
        if (num(k.repeatDelay)) out.push("input type:keyboard repeat_delay " + Math.round(k.repeatDelay));
        if (num(k.repeatRate)) out.push("input type:keyboard repeat_rate " + Math.round(k.repeatRate));
        function tp(key, v) { if (v === "enabled" || v === "disabled") out.push("input type:touchpad " + key + " " + v); }
        tp("tap", t.tap); tp("natural_scroll", t.naturalScroll); tp("dwt", t.disableWhileTyping);
        if (num(t.accel)) out.push("input type:touchpad pointer_accel " + Math.max(-1, Math.min(1, t.accel)));
        // tasti in più del PC, prima di quelle dell'utente
        hardwareCommands().forEach(function (c) { out.push(c); });
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
    property var appliedHw: ({})    // tasti in più associati a caldo: se escono dall'elenco (conflitto nuovo, tastiera scollegata) si sciolgono
    property string lastConf: ""
    Timer { id: sync; interval: 400; onTriggered: root.syncNow() }
    Connections { target: Config; function onSwayChanged() { sync.restart(); } }

    function syncNow() {
        if (labwc) { syncLabwc(); return; }
        if (!active) return;
        var live = inputWallpaperCommands(), next = {};
        // Una scorciatoia di Vela tolta torna libera subito (quella originale del config torna al prossimo reload).
        var combos = {};
        Config.sway.keybindings.forEach(function (b) { var c = bindCommand(b); if (c) combos[c.split(" ")[1]] = true; });
        for (var old in appliedBinds) if (!combos[old]) run("unbindsym " + old);
        appliedBinds = combos;
        var hw = {};
        hardwareShown.forEach(function (b) { hw[hwUnbind(b)] = true; });
        for (var oldHw in appliedHw) if (!hw[oldHw]) run(oldHw);
        appliedHw = hw;
        live.forEach(function (c) { next[c] = true; if (!applied[c]) run(c); });
        applied = next;
        var text = "# Generato da Vela (Impostazioni): non modificare a mano, le modifiche verrebbero perse.\n"
                 + live.concat(execCommands(), outputCommands()).join("\n") + "\n";
        if (text !== lastConf) { lastConf = text; confText = text; mkdir.running = true; }
    }

    // labwc: gli schermi confermati diventano righe di wlr-randr in uno script che l'autostart della sessione esegue.
    property string labwcText: ""
    function syncLabwc() {
        var o = Config.sway.outputs, lines = [];
        for (var name in o) { var a = randrArgs(name, o[name]); if (a.length > 0) lines.push(a.join(" ")); }
        var text = "#!/bin/sh\n# Generato da Vela (Impostazioni): non modificare a mano, le modifiche verrebbero perse.\n" + lines.join("\n") + "\n";
        if (text !== lastConf) { lastConf = text; labwcText = text; mkdirLabwc.running = true; }
    }
    Process { id: mkdirLabwc; command: ["mkdir", "-p", Config.userDir + "/labwc.d"]; onExited: labwcFile.setText(root.labwcText) }
    FileView { id: labwcFile; path: Config.userDir + "/labwc.d/vela-outputs.sh"; atomicWrites: true; printErrors: false }

    property string confText: ""
    Process { id: mkdir; command: ["mkdir", "-p", root.confDir]; onExited: confFile.setText(root.confText) }
    FileView { id: confFile; path: root.confPath; atomicWrites: true; printErrors: false }

    // --- schermi, con conferma (si torna indietro se non si conferma entro 15 secondi) -----------
    property var pending: null        // {items: {<schermo>: {prev, next}}}: tutte le modifiche in attesa di conferma
    property int countdown: 0

    function find(name) {
        for (var i = 0; i < outputs.length; i++) if (outputs[i].name === name) return outputs[i];
        return null;
    }
    function snapshot(o) { return { mode: o.mode, scale: o.scale, transform: o.transform, x: o.x, y: o.y, enabled: o.active }; }

    // --- modalità rapide degli schermi (D-044) ----------------------------------------------
    function isInternal(o) { return /^(eDP|LVDS|DSI)/.test(o.name); }
    // Lo schermo "interno": quello con nome da pannello di portatile (eDP, LVDS, DSI), altrimenti il primo in ordine
    // alfabetico (Sway non garantisce l'ordine dell'elenco: la scelta deve restare la stessa a ogni lettura).
    readonly property string internalName: {
        var best = "";
        for (var i = 0; i < outputs.length; i++) {
            var n = outputs[i].name;
            if (isInternal(outputs[i])) return n;
            if (best === "" || n < best) best = n;
        }
        return best;
    }
    // Modalità in uso con almeno due schermi: "internal" (solo l'interno), "external" (solo gli esterni), "extend" (tutti),
    // "mirror" (tutti, con l'immagine dell'interno duplicata sugli esterni); "" se non si sa.
    readonly property string displayMode: {
        var inn = find(internalName);
        if (outputs.length < 2 || !inn) return "";
        var ext = outputs.some(function (o) { return o.name !== internalName && o.active; });
        if (inn.active && !ext) return "internal";
        if (!inn.active && ext) return "external";
        if (inn.active && ext) return mirrorPairs.length > 0 ? "mirror" : "extend";
        return "";
    }

    // --- duplicazione (D-044, passo 4): Sway non duplica da solo; `wl-mirror` mostra a schermo intero sullo schermo
    // esterno l'immagine dell'interno, mentre gli schermi restano estesi. I processi vivono con Vela (non sopravvivono a un
    // riavvio di Vela) e si fermano con qualsiasi altra modalità o con il ripristino.
    property bool hasMirror: false
    Process {
        command: ["sh", "-c", "command -v wl-mirror"]
        running: true
        onExited: code => root.hasMirror = (code === 0)
    }
    property var mirrorPairs: []          // [{src, dst}]
    property bool mirrorRuleSet: false
    function stopMirror() { mirrorPairs = []; }
    function validName(n) { return typeof n === "string" && /^[A-Za-z0-9_\-]+$/.test(n); }
    function startMirror() {
        var inn = find(internalName);
        if (!hasMirror || !inn || !inn.active) return;
        var pairs = outputs.filter(function (o) { return o.active && o.name !== internalName && validName(o.name); })
                           .map(function (o) { return { src: inn.name, dst: o.name }; });
        if (pairs.length === 0 || !validName(inn.name)) return;
        // La finestra del duplicato non deve rubare il focus.
        if (!labwc && !mirrorRuleSet) { run('no_focus [title="vela-mirror"]'); mirrorRuleSet = true; }
        mirrorPairs = pairs;
    }
    Instantiator {
        model: root.mirrorPairs
        delegate: Process {
            required property var modelData
            command: ["wl-mirror", "--title", "vela-mirror", "--fullscreen-output", modelData.dst, modelData.src]
            running: true
            Component.onDestruction: running = false
        }
    }
    // Dopo aver acceso gli schermi si aspetta un attimo che Sway li abbia pronti.
    Timer { id: mirrorStart; interval: 1200; onTriggered: root.startMirror() }

    // Dimensione logica di uno schermo (pixel dopo scala e rotazione), anche da spento (modo preferito).
    function logicalSize(o) {
        var m = /^(\d+)x(\d+)/.exec(o.active && o.mode !== "" ? o.mode : (o.modes.length > 0 ? o.modes[0] : ""));
        if (!m) return { w: 0, h: 0 };
        var w = parseInt(m[1]), h = parseInt(m[2]);
        if (/90|270/.test(o.transform || "")) { var t = w; w = h; h = t; }
        var sc = o.scale > 0 ? o.scale : 1;
        return { w: Math.round(w / sc), h: Math.round(h / sc) };
    }

    // Sposta uno schermo accanto all'altro (solo con due schermi accesi): `side` = "left", "right", "above" o "below" è il lato
    // dell'altro schermo su cui va. Gli schermi restano accostati e allineati sul bordo alto (o sinistro); le coordinate si
    // riportano a zero in alto a sinistra. Con la conferma di 15 s. Restituisce false se non si può.
    function placeOutput(name, side) {
        var o = find(name);
        var act = outputs.filter(function (a) { return a.active; });
        if (!o || !o.active || act.length !== 2 || ["left", "right", "above", "below"].indexOf(side) < 0) return false;
        var ref = act[0].name === name ? act[1] : act[0];
        var x = ref.x, y = ref.y;
        if (side === "left") x = ref.x - o.w;
        else if (side === "right") x = ref.x + ref.w;
        else if (side === "above") y = ref.y - o.h;
        else y = ref.y + ref.h;
        var dx = Math.min(x, ref.x), dy = Math.min(y, ref.y);
        setOutputs([{ name: name, props: { x: x - dx, y: y - dy } }, { name: ref.name, props: { x: ref.x - dx, y: ref.y - dy } }]);
        return true;
    }

    // Applica una modalità ("internal", "external", "extend"): accende e spegne gli schermi e li affianca da sinistra a destra,
    // tutto sotto un'unica conferma. Restituisce false se la modalità non esiste o manca lo schermo interno.
    function applyDisplayMode(kind) {
        var inn = find(internalName);
        if (!inn || outputs.length < 2) return false;
        if (kind === "mirror" && !hasMirror) return false;
        stopMirror();
        mirrorStart.stop();
        var wantMirror = kind === "mirror";
        if (wantMirror) kind = "extend";
        var ext = outputs.filter(function (o) { return o.name !== internalName; });
        var changes = [], x = 0;
        function place(o) {
            changes.push({ name: o.name, props: { enabled: true, x: x, y: 0 } });
            x += logicalSize(o).w;
        }
        if (kind === "internal") {
            place(inn);
            ext.forEach(function (o) { changes.push({ name: o.name, props: { enabled: false } }); });
        } else if (kind === "external") {
            ext.forEach(place);
            changes.push({ name: inn.name, props: { enabled: false } });
        } else if (kind === "extend") {
            place(inn);
            ext.forEach(place);
        } else {
            return false;
        }
        setOutputs(changes);
        if (wantMirror) mirrorStart.restart();
        return true;
    }

    function setOutput(name, props) { setOutputs([{ name: name, props: props }]); }

    // Applica insieme le modifiche di più schermi ([{name, props}]) sotto un'unica conferma: se non si conferma entro
    // 15 s tornano tutte allo stato precedente. Gli schermi da accendere vanno prima di quelli da spegnere, per non
    // restare mai senza schermi.
    function setOutputs(changes) {
        var items = {};
        if (pending) for (var k in pending.items) items[k] = pending.items[k];
        var cmds = [];
        changes.forEach(function (ch) {
            var cur = find(ch.name);
            if (!cur) return;
            var it = items[ch.name] || { prev: snapshot(cur), next: snapshot(cur) };
            var next = {};
            for (var q in it.next) next[q] = it.next[q];
            for (var p in ch.props) next[p] = ch.props[p];
            items[ch.name] = { prev: it.prev, next: next };
            var c = outCmd(ch.name, ch.props);
            if (c.length > 0) cmds.push({ off: ch.props.enabled === false, c: c });
        });
        if (cmds.length === 0) return;
        pending = { items: items };
        cmds.sort(function (a, b) { return (a.off ? 1 : 0) - (b.off ? 1 : 0); });
        cmds.forEach(function (x) { run(x.c); });
        countdown = 15;
        tick.restart();
        reread.restart();
    }
    function confirm() {
        if (!pending) return;
        var map = {};
        for (var n in pending.items) {
            var v = pending.items[n].next;
            map["outputs." + n + ".mode"] = v.mode;
            map["outputs." + n + ".scale"] = v.scale;
            map["outputs." + n + ".x"] = v.x;
            map["outputs." + n + ".y"] = v.y;
            map["outputs." + n + ".transform"] = v.transform;
            map["outputs." + n + ".enabled"] = v.enabled;
        }
        Settings.setMany("sway", map);
        pending = null;
        tick.stop();
    }
    function revert() {
        if (!pending) return;
        mirrorStart.stop();
        stopMirror();
        var cmds = [];
        for (var n in pending.items) {
            var prev = pending.items[n].prev;
            cmds.push({ off: prev.enabled === false, c: outCmd(n, prev) });
        }
        cmds.sort(function (a, b) { return (a.off ? 1 : 0) - (b.off ? 1 : 0); });
        cmds.forEach(function (x) { if (x.c.length > 0) run(x.c); });
        // wlr-randr non accende lo schermo se la modalità richiesta non esiste: un `--on` a parte evita di restare senza schermi.
        if (labwc) for (var m in pending.items) if (pending.items[m].prev.enabled !== false && validName(m)) run(["wlr-randr", "--output", m, "--on"]);
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
