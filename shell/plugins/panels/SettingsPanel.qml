// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello Impostazioni, gradino 1: aspetto (schede Barra e Tema). Scrive solo settings.jsonc (D-021),
// con anteprima immediata. Su: ↑/↓ · ←/→ cambia valore · Invio modifica · Canc ripristina · Tab cambia scheda.
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "../../core/icons.js" as Icons
import "../../core/swayconf.js" as SwayConf
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "settings"
    cardWidth: 860
    cardHeight: 600
    centered: true
    readonly property int sidebarWidth: 190

    readonly property int headerHeight: Theme.rowHeight
    readonly property int sectionHeight: 26
    readonly property int footerHeight: 28
    readonly property int maxRows: 14

    property int tab: 0                       // indice in `tabs`
    // Le categorie del compositor compaiono solo se il compositor attivo ha un backend che le gestisce.
    readonly property var tabs: {
        var t = [{ id: "bar", label: "Barra" }, { id: "theme", label: "Tema" }, { id: "weather", label: "Meteo" }];
        if (Compositors.activeHasBackend && SwayBackend.active) {
            t.push({ id: "outputs", label: "Schermi" }, { id: "input", label: "Tastiera e touchpad" }, { id: "wallpaper", label: "Sfondo" },
                   { id: "keys", label: "Scorciatoie" }, { id: "autostart", label: "Avvio automatico" },
                   { id: "rules", label: "Regole delle finestre" }, { id: "gaps", label: "Bordi e spazi" });
        }
        t.push({ id: "compositor", label: "Compositor" }, { id: "about", label: "Informazioni" });
        return t;
    }
    readonly property var tabNames: tabs.map(function (t) { return t.label; })
    readonly property string tabId: (tabs[tab] || tabs[0]).id
    property var editing: null                // riga in modifica (colore o testo)
    property bool confirmReset: false
    property string currentKey: ""
    property string note: ""

    // --- righe ------------------------------------------------------------------------
    function fmt(v, dec) { return dec > 0 ? v.toFixed(dec) : String(Math.round(v)); }

    // `fallback`: valore da cui partire quando l'impostazione non c'è (null = predefinito di Sway).
    function number(file, path, label, min, max, step, dec, fallback) {
        var v = Settings.get(file, path), unset = (v === null || v === undefined);
        return { kind: "number", file: file, path: path, label: label, min: min, max: max, step: step, dec: dec,
                 value: unset ? (fallback !== undefined ? fallback : min) : v, text: unset ? "predefinito" : fmt(v, dec),
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    // Righe che non scrivono in settings.jsonc ma chiamano `commit` (es. gli schermi, con conferma).
    function numberC(key, label, min, max, step, dec, value, commit) {
        return { kind: "number", label: label, min: min, max: max, step: step, dec: dec, value: value, text: fmt(value, dec),
                 commit: commit, key: key };
    }
    function choiceC(key, label, options, value, commit) {
        var t = String(value);
        options.forEach(function (o) { if (o.v === value) t = o.t; });
        return { kind: "choice", label: label, options: options, value: value, text: t, commit: commit, key: key };
    }
    function choice(file, path, label, options) {
        var v = Settings.get(file, path), t = (v === null || v === undefined) ? "predefinito" : String(v);
        options.forEach(function (o) { if (o.v === v) t = o.t; });
        return { kind: "choice", file: file, path: path, label: label, options: options, value: v, text: t,
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function color(file, path, label) {
        var v = Settings.get(file, path);
        return { kind: "color", file: file, path: path, label: label, value: v || "#000000", text: v || "non impostato",
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function textRow(file, path, label) {
        var v = Settings.get(file, path), unset = (v === null || v === undefined || v === "");
        return { kind: "text", file: file, path: path, label: label, value: unset ? "" : v, text: unset ? "predefinito" : v,
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function header(label) { return { kind: "header", label: label, key: "h:" + label }; }

    readonly property var zoneOrder: ["left", "center", "right", "hidden"]
    readonly property var zoneLabels: ({ left: "Sinistra", center: "Centro", right: "Destra", hidden: "Nascosto" })

    function barRows() {
        var out = [header("Aspetto")];
        out.push(choice("shell", "bar.position", "Posizione", [{ v: "top", t: "in alto" }, { v: "bottom", t: "in basso" }]));
        out.push(number("theme", "layout.barHeight", "Altezza", 18, 48, 2, 0));
        out.push(number("theme", "font.barSize", "Dimensione del testo nella barra", 9, 22, 1, 0));
        out.push(number("theme", "layout.barRadius", "Angoli della barra", 0, 16, 1, 0));
        out.push(number("theme", "barOpacity", "Trasparenza dello sfondo (opacità)", 0, 1, 0.05, 2));
        out.push(header("Elementi"));
        var mods = Config.shell.bar.modules, used = {};
        ["left", "center", "right"].forEach(function (z) {
            (mods[z] || []).forEach(function (n) {
                used[n] = true;
                out.push({ kind: "module", name: n, zone: z, text: zoneLabels[z], key: "mod:" + n });
            });
        });
        BarModules.names.forEach(function (n) {
            if (!used[n]) out.push({ kind: "module", name: n, zone: "hidden", text: zoneLabels.hidden, key: "mod:" + n });
        });
        out.push({ kind: "action", label: "Ripristina gli elementi di default", act: "resetModules", key: "a:resetModules" });
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function themeRows() {
        var out = [header("Preset")];
        out.push({ kind: "action", label: "Scuro (predefinito)", act: "presetDark", key: "a:dark" });
        out.push({ kind: "action", label: "Chiaro", act: "presetLight", key: "a:light" });
        out.push(header("Colori"));
        var names = [["background", "Sfondo"], ["surface", "Superficie"], ["border", "Bordo"], ["foreground", "Testo"],
                     ["muted", "Testo attenuato"], ["dim", "Testo debole"], ["accent", "Accento"],
                     ["warning", "Avviso"], ["error", "Errore"]];
        names.forEach(function (n) { out.push(color("theme", "colors." + n[0], n[1])); });
        out.push(header("Carattere e forma"));
        out.push(textRow("theme", "font.family", "Carattere"));
        out.push(number("theme", "font.size", "Dimensione del testo (pannelli, menu, notifiche)", 9, 22, 1, 0));
        out.push(number("theme", "layout.radius", "Angoli di pannelli, menu e notifiche", 0, 16, 1, 0));
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function weatherRows() {
        var w = Config.shell.weather;
        var out = [header("Meteo")];
        var on = typeof w.latitude === "number" && typeof w.longitude === "number";
        out.push(info("Stato", on ? "attivo" : "spento: scegli una città", on ? "accent" : "warn"));
        out.push({ kind: "search", label: "Città", text: w.placeName ? w.placeName : (on ? "coordinate impostate" : "non impostata"),
                   over: Settings.overridden("shell", "weather.placeName"), key: "search:city" });
        out.push(choice("shell", "weather.units", "Unità di misura", [{ v: "metric", t: "metriche (°C)" }, { v: "imperial", t: "imperiali (°F)" }]));
        if (Geocoding.busy) out.push(info("Ricerca di «" + Geocoding.query + "»", "in corso…"));
        else if (Geocoding.error !== "") out.push(info("Ricerca di «" + Geocoding.query + "»", Geocoding.error, "warn"));
        if (Geocoding.results.length > 0) {
            out.push(header("Risultati per «" + Geocoding.query + "»"));
            Geocoding.results.forEach(function (r, i) {
                out.push({ kind: "place", label: r.label, text: r.lat.toFixed(2) + ", " + r.lon.toFixed(2), place: r, key: "place:" + i });
            });
        }
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    // --- schermi, tastiera, touchpad, sfondo (backend Sway) -------------------------------------
    property var pendingConfirm: null     // {text, fn}: conferma generica (es. modifica del config di Sway)

    function uniq(a) { var seen = {}, out = []; a.forEach(function (x) { if (!seen[x]) { seen[x] = true; out.push(x); } }); return out; }

    function outputsRows() {
        var out = [];
        if (SwayBackend.pending) {
            out.push(header("Conferma"));
            out.push(info("Mantenere queste impostazioni?", "tra " + SwayBackend.countdown + " s si torna indietro", "warn"));
            out.push({ kind: "action", label: "Mantieni", act: "keepOutputs", key: "a:keep" });
            out.push({ kind: "action", label: "Ripristina ora", act: "revertOutputs", key: "a:revert" });
        }
        var outs = SwayBackend.outputs, activeCount = outs.filter(function (o) { return o.active; }).length;
        outs.forEach(function (o) {
            var n = o.name, k = "o:" + n + ":";
            out.push(header(n + (o.label ? " — " + o.label : "")));
            if (o.active) {
                out.push(choiceC(k + "mode", "Risoluzione e frequenza", uniq(o.modes).map(function (m) { return { v: m, t: m }; }), o.mode,
                                 function (v) { SwayBackend.setOutput(n, { mode: v }); }));
                out.push(numberC(k + "scale", "Scala", 0.5, 3, 0.25, 2, o.scale, function (v) { SwayBackend.setOutput(n, { scale: v }); }));
                out.push(choiceC(k + "transform", "Rotazione", [{ v: "normal", t: "normale" }, { v: "90", t: "90°" }, { v: "180", t: "180°" }, { v: "270", t: "270°" }],
                                 o.transform, function (v) { SwayBackend.setOutput(n, { transform: v }); }));
                if (outs.length > 1) {
                    out.push(numberC(k + "x", "Posizione orizzontale", -10000, 20000, 10, 0, o.x, function (v) { SwayBackend.setOutput(n, { x: v }); }));
                    out.push(numberC(k + "y", "Posizione verticale", -10000, 20000, 10, 0, o.y, function (v) { SwayBackend.setOutput(n, { y: v }); }));
                }
            }
            // Con un solo schermo acceso non si può spegnere.
            if (outs.length > 1 && (!o.active || activeCount > 1))
                out.push(choiceC(k + "enabled", "Schermo", [{ v: true, t: "acceso" }, { v: false, t: "spento" }], o.active,
                                 function (v) { SwayBackend.setOutput(n, { enabled: v }); }));
        });
        if (outs.length === 0) out.push(info("Schermi", "nessuno rilevato", "warn"));
        if (SwayBackend.lastError !== "") out.push(info("Errore di Sway", SwayBackend.lastError, "warn"));
        out.push(header("Scelte salvate"));
        out.push({ kind: "action", label: "Dimentica le impostazioni salvate degli schermi", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    readonly property var onOff: [{ v: "enabled", t: "sì" }, { v: "disabled", t: "no" }]

    function inputRows() {
        var out = [header("Tastiera")];
        out.push(textRow("sway", "input.keyboard.layout", "Layout (es. it oppure it,us)"));
        out.push(textRow("sway", "input.keyboard.variant", "Variante"));
        out.push(textRow("sway", "input.keyboard.options", "Opzioni (es. grp:alt_shift_toggle)"));
        out.push(number("sway", "input.keyboard.repeatDelay", "Ritardo di ripetizione (ms)", 100, 1000, 50, 0, 600));
        out.push(number("sway", "input.keyboard.repeatRate", "Ripetizioni al secondo", 5, 60, 1, 0, 25));
        out.push(header("Touchpad"));
        if (SwayBackend.hasTouchpad) {
            out.push(choice("sway", "input.touchpad.tap", "Tocco per cliccare", onOff));
            out.push(choice("sway", "input.touchpad.naturalScroll", "Scorrimento naturale", onOff));
            out.push(choice("sway", "input.touchpad.disableWhileTyping", "Disattiva mentre si scrive", onOff));
            out.push(number("sway", "input.touchpad.accel", "Velocità del puntatore", -1, 1, 0.1, 1, 0));
        } else {
            out.push(info("Touchpad", "nessuno rilevato"));
        }
        if (SwayBackend.lastError !== "") out.push(info("Errore di Sway", SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function wallpaperRows() {
        var out = [header("Sfondo")];
        out.push(textRow("sway", "wallpaper.path", "Immagine (percorso)"));
        out.push(choice("sway", "wallpaper.mode", "Adattamento", [{ v: "fill", t: "riempi" }, { v: "fit", t: "adatta" }, { v: "stretch", t: "allunga" },
                                                                 { v: "center", t: "centra" }, { v: "tile", t: "affianca" }]));
        out.push(color("sway", "wallpaper.color", "Colore (senza immagine)"));
        if (SwayBackend.lastError !== "") out.push(info("Errore di Sway", SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function persistenceRows() {
        var out = [header("Persistenza al login (Sway)")];
        out.push(info("File generato da Vela", SwayBackend.confPath));
        if (SwayBackend.hasInclude) {
            out.push(info("include nel config di Sway", "presente", "accent"));
        } else {
            out.push(info("include nel config di Sway", "mancante: gli schermi non si ricordano al login", "warn"));
            out.push({ kind: "action", label: "Aggiungi la riga include al config di Sway (con copia di sicurezza)", act: "addInclude", key: "a:include" });
        }
        return out;
    }

    // --- scorciatoie, avvio automatico, regole, bordi e spazi (Sway) ---------------------------------
    function list(name) { return (Config.sway[name] || []).slice(); }
    function setList(name, arr) { Settings.set("sway", name, arr); }

    function keysRows() {
        var out = [header("Scorciatoie di Vela")];
        var mine = Config.sway.keybindings;
        mine.forEach(function (b) {
            out.push({ kind: "bind", own: true, combo: b.combo, command: b.command, label: b.combo,
                       text: b.command ? b.command : "disattivata", key: "kb:" + b.combo });
        });
        if (mine.length === 0) out.push(info("Nessuna", "aggiungine una o cambia una del config di Sway"));
        out.push({ kind: "action", label: "Aggiungi una scorciatoia", act: "addBind", key: "a:addbind" });
        var theirs = SwayBackend.userConfig.binds;
        out.push(header("Dal config di Sway (la tua scelta sostituisce quella del config)"));
        var vars = SwayBackend.userConfig.vars;
        theirs.forEach(function (b) {
            var n = SwayConf.normalize(b.combo, vars);
            var over = mine.some(function (m) { return SwayConf.normalize(m.combo, vars) === n; });
            out.push({ kind: "bind", own: false, combo: b.combo, command: b.command, label: b.combo,
                       text: (over ? "sostituita · " : "") + b.command, over: over, key: "ub:" + b.combo });
        });
        if (theirs.length === 0) out.push(info("Config di Sway", "nessuna scorciatoia trovata"));
        if (SwayBackend.lastError !== "") out.push(info("Errore di Sway", SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function autostartRows() {
        var out = [header("Avviati da Vela")];
        Config.sway.autostart.forEach(function (c, i) { out.push({ kind: "auto", idx: i, label: c, text: "", key: "au:" + i + ":" + c }); });
        if (Config.sway.autostart.length === 0) out.push(info("Nessuno", "aggiungine uno"));
        out.push({ kind: "action", label: "Aggiungi un programma", act: "addAuto", key: "a:addauto" });
        if (!SwayBackend.hasInclude) out.push(info("Attenzione", "serve l'include nel config di Sway (categoria Compositor)", "warn"));
        out.push(header("Dal config di Sway (sola lettura)"));
        SwayBackend.userConfig.execs.forEach(function (e, i) { out.push(info(e.command, e.always ? "a ogni reload" : "all'avvio")); });
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function rulesRows() {
        var out = [header("Regole di Vela")];
        Config.sway.rules.forEach(function (rl, i) { out.push({ kind: "rule", idx: i, label: rl.criteria, text: rl.command, key: "ru:" + i + ":" + rl.criteria }); });
        if (Config.sway.rules.length === 0) out.push(info("Nessuna", "aggiungine una (es. [app_id=\"foot\"] floating enable)"));
        out.push({ kind: "action", label: "Aggiungi una regola", act: "addRule", key: "a:addrule" });
        out.push(header("Dal config di Sway (sola lettura)"));
        SwayBackend.userConfig.rules.forEach(function (rl) { out.push(info(rl.criteria, rl.command)); });
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function gapsRows() {
        var out = [header("Finestre")];
        out.push(number("sway", "gaps.inner", "Spazio tra le finestre (px)", 0, 50, 1, 0, 0));
        out.push(number("sway", "gaps.outer", "Spazio dal bordo dello schermo (px)", 0, 50, 1, 0, 0));
        out.push(number("sway", "gaps.border", "Spessore del bordo (px, finestre nuove)", 0, 10, 1, 0, 1));
        out.push(choice("sway", "gaps.smartGaps", "Niente spazi con una sola finestra", [{ v: "on", t: "sì" }, { v: "off", t: "no" }, { v: "inverse_outer", t: "solo esterni" }]));
        out.push(choice("sway", "gaps.smartBorders", "Niente bordi con una sola finestra", [{ v: "on", t: "sì" }, { v: "off", t: "no" }, { v: "no_gaps", t: "solo senza spazi" }]));
        if (SwayBackend.lastError !== "") out.push(info("Errore di Sway", SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: "Ripristina questa scheda", act: "resetTab", key: "a:resetTab" });
        return out;
    }

    // Inserimento a più passi (es. combinazione, poi comando).
    property var steps: null
    property int stepIndex: 0
    property var answers: []
    property var finishFn: null

    function stepLabel() {
        var st = steps[stepIndex];
        return typeof st.label === "function" ? st.label(answers) : st.label;
    }
    function startSteps(stepList, finish) {
        steps = stepList; stepIndex = 0; answers = []; finishFn = finish; note = "";
        editing = { kind: "steps", label: stepLabel() };
        field.text = steps[0].initial || "";
        field.forceActiveFocus();
        field.selectAll();
    }
    function stepSubmit() {
        var st = steps[stepIndex], t = field.text.trim();
        if (t === "" && !st.allowEmpty) { note = "Valore vuoto"; return; }
        if (t !== "" && !SwayBackend.oneLine(t)) { note = "Solo una riga, senza caratteri di controllo"; return; }
        if (st.validate) { var err = st.validate(t); if (err) { note = err; return; } }
        answers = answers.concat([t]);
        note = st.after ? st.after(answers) : "";
        if (stepIndex + 1 < steps.length) {
            stepIndex++;
            editing = { kind: "steps", label: stepLabel() };
            field.text = steps[stepIndex].initial || "";
            field.forceActiveFocus();
            field.selectAll();
        } else {
            var fn = finishFn, a = answers;
            var keep = note;
            cancelEdit();
            note = keep;
            fn(a);
        }
    }

    function upsertBind(combo, command) {
        var a = list("keybindings"), done = false;
        for (var i = 0; i < a.length; i++) if (a[i].combo === combo) { a[i] = { combo: combo, command: command }; done = true; }
        if (!done) a.push({ combo: combo, command: command });
        setList("keybindings", a);
    }
    function editBind(r) {
        startSteps([{ label: "Comando per " + r.combo + " (vuoto = disattiva)", initial: r.own ? (r.command || "") : r.command, allowEmpty: true }],
                   function (a) { upsertBind(r.combo, a[0]); });
    }
    function addBind() {
        startSteps([
            { label: "Combinazione (es. $mod+Shift+e)", validate: function (t) { return /^[A-Za-z0-9_$+\-]+$/.test(t) ? "" : "Combinazione non valida: usare nomi come $mod+Shift+e"; },
              after: function (a) {
                  var c = SwayBackend.conflictFor(a[0], "");
                  return c ? "Attenzione: «" + a[0] + "» è già assegnata a «" + c.command + "» (" + (c.source === "sway" ? "config di Sway" : "Vela") + "): sarà sostituita" : "";
              } },
            { label: function (a) { return "Comando per " + a[0] + " (es. exec foot)"; } }
        ], function (a) { upsertBind(a[0], a[1]); });
    }
    function addAuto() { startSteps([{ label: "Programma da avviare (es. nm-applet --indicator)" }], function (a) { var l = list("autostart"); l.push(a[0]); setList("autostart", l); }); }
    function editAuto(r) { startSteps([{ label: "Programma da avviare", initial: r.label }], function (a) { var l = list("autostart"); l[r.idx] = a[0]; setList("autostart", l); }); }
    function addRule() {
        startSteps([
            { label: "Criteri (es. app_id=\"foot\")" },
            { label: function (a) { return "Comando per [" + a[0].replace(/^\[|\]$/g, "") + "] (es. floating enable)"; } }
        ], function (a) { var l = list("rules"); l.push({ criteria: a[0], command: a[1] }); setList("rules", l); });
    }
    function editRule(r) {
        startSteps([{ label: "Comando per " + r.label, initial: r.text }], function (a) { var l = list("rules"); l[r.idx] = { criteria: l[r.idx].criteria, command: a[0] }; setList("rules", l); });
    }
    function removeAt(name, idx) { var l = list(name); l.splice(idx, 1); setList(name, l); }
    function removeBind(combo) { setList("keybindings", list("keybindings").filter(function (b) { return b.combo !== combo; })); }

    readonly property string homeUrl: "https://github.com/akamizi/vela"
    FileView {
        id: versionFile
        path: Quickshell.shellDir + "/../VERSION"
        blockLoading: true
        printErrors: false
    }
    readonly property string version: { try { return versionFile.text().trim() || "sconosciuta"; } catch (e) { return "sconosciuta"; } }

    function aboutRows() {
        var out = [{ kind: "logo", key: "logo" }];
        out.push(header("Informazioni"));
        out.push(info("Versione", version));
        out.push(info("Licenza", "EUPL-1.2"));
        out.push(info("Compositor", Compositors.active ? Compositors.active.name : "non riconosciuto"));
        out.push(info("Configurazione", Config.userDir));
        out.push(header("Progetto"));
        out.push(info("Indirizzo", homeUrl.replace("https://", "")));
        out.push({ kind: "action", label: "Apri la pagina del progetto", act: "openHome", key: "a:home" });
        out.push({ kind: "action", label: "Apri le note di rilascio", act: "openReleases", key: "a:releases" });
        return out;
    }

    function info(label, text, tone) { return { kind: "info", label: label, text: text, tone: tone || "", key: "i:" + label }; }

    function compositorRows() {
        var out = [header("Compositor rilevati")];
        Compositors.compositors.forEach(function (c) {
            var st = [];
            st.push(c.installed ? "installato" : "non installato");
            if (c.running) st.push("in esecuzione");
            if (c.active) st.push("sessione attuale");
            out.push(info(c.name, st.join(" · "), c.active ? "accent" : ""));
        });
        var a = Compositors.active;
        if (a === null) {
            out.push(info("Sessione", "compositor non riconosciuto", "warn"));
            return out;
        }
        out.push(header("Backend di Vela per " + a.name));
        out.push(info("Stato", a.backend ? "disponibile" : "non ancora disponibile: barra e impostazioni limitate", a.backend ? "" : "warn"));
        out.push(info("File di configurazione", a.config));
        if (Compositors.categories.length > 0) out.push(header("Categorie di impostazioni"));
        Compositors.categories.forEach(function (c) { out.push(info(c.label, c.available ? "disponibile" : "in arrivo", c.available ? "accent" : "")); });
        if (a.id === "sway" && SwayBackend.active) out = out.concat(persistenceRows());
        return out;
    }

    readonly property var rows: {
        switch (tabId) {
        case "bar": return barRows();
        case "theme": return themeRows();
        case "weather": return weatherRows();
        case "outputs": return outputsRows();
        case "input": return inputRows();
        case "wallpaper": return wallpaperRows();
        case "keys": return keysRows();
        case "autostart": return autostartRows();
        case "rules": return rulesRows();
        case "gaps": return gapsRows();
        case "about": return aboutRows();
        default: return compositorRows();
        }
    }
    function selectable(r) { return r && r.kind !== "header" && r.kind !== "info" && r.kind !== "logo"; }
    function current() { return rows[list.currentIndex] || null; }

    // La selezione è ricordata per chiave, non per indice: l'elenco si ricostruisce a ogni modifica.
    function select(i) {
        list.currentIndex = i;
        if (i >= 0 && i < rows.length) { currentKey = rows[i].key; list.positionViewAtIndex(i, ListView.Contain); }
    }

    function move(delta) {
        var n = rows.length, i = list.currentIndex;
        for (var step = 0; step < n; step++) {
            i = (i + delta + n) % n;
            if (selectable(rows[i])) { select(i); return; }
        }
    }

    // Dopo ogni cambio (anteprima dal vivo) la selezione resta sulla stessa riga. Il ripristino è
    // rimandato: la ListView azzera currentIndex quando cambia il modello.
    function restoreSelection() {
        var idx = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].key === currentKey) { idx = i; break; }
        if (idx < 0) for (var j = 0; j < rows.length; j++) if (selectable(rows[j])) { idx = j; break; }
        list.currentIndex = idx;      // la chiave resta quella ricordata
        if (idx >= 0) list.positionViewAtIndex(idx, ListView.Contain);
    }
    onRowsChanged: Qt.callLater(restoreSelection)

    onTabChanged: {
        currentKey = ""; confirmReset = false; pendingConfirm = null;
        Qt.callLater(function () { list.positionViewAtBeginning(); });
        if (tabId === "compositor") Compositors.refresh();
        if (tabId === "outputs" || tabId === "input" || tabId === "compositor" || tabId === "keys" || tabId === "autostart" || tabId === "rules") SwayBackend.refresh();
    }

    // --- azioni -----------------------------------------------------------------------
    function round(v, dec) { var m = Math.pow(10, dec); return Math.round(v * m) / m; }

    function step(r, dir) {
        if (r.kind === "number") {
            var v = Math.max(r.min, Math.min(r.max, round(r.value + dir * r.step, r.dec + 2)));
            if (r.commit) r.commit(v); else Settings.set(r.file, r.path, v);
        } else if (r.kind === "choice") {
            var idx = -1;
            r.options.forEach(function (o, i) { if (o.v === r.value) idx = i; });
            if (idx < 0 && dir < 0) idx = 0;       // non impostato: ← porta all'ultima, → alla prima
            var nv = r.options[(idx + dir + r.options.length) % r.options.length].v;
            if (r.commit) r.commit(nv); else Settings.set(r.file, r.path, nv);
        } else if (r.kind === "module") {
            moveModule(r, dir);
        }
    }

    function modulesCopy() {
        var m = Config.shell.bar.modules;
        return { left: (m.left || []).slice(), center: (m.center || []).slice(), right: (m.right || []).slice() };
    }
    function writeModules(m) {
        Settings.setMany("shell", { "bar.modules.left": m.left, "bar.modules.center": m.center, "bar.modules.right": m.right });
    }
    // ←/→: passa alla zona vicina (Sinistra, Centro, Destra, Nascosto); in coda alla zona.
    function moveModule(r, dir) {
        var i = zoneOrder.indexOf(r.zone), j = i + dir;
        if (j < 0 || j >= zoneOrder.length) return;
        var m = modulesCopy();
        if (r.zone !== "hidden") m[r.zone] = m[r.zone].filter(function (n) { return n !== r.name; });
        if (zoneOrder[j] !== "hidden") m[zoneOrder[j]].push(r.name);
        writeModules(m);
    }
    // Maiusc+↑/↓: sposta nella zona.
    function reorder(r, dir) {
        if (r.zone === "hidden") return;
        var m = modulesCopy(), a = m[r.zone], i = a.indexOf(r.name), j = i + dir;
        if (i < 0 || j < 0 || j >= a.length) return;
        a.splice(i, 1);
        a.splice(j, 0, r.name);
        writeModules(m);
    }

    readonly property var light: ({
        "colors.background": "#f5f5f5", "colors.surface": "#ffffff", "colors.border": "#dcdcdc",
        "colors.foreground": "#1f2328", "colors.muted": "#656d76", "colors.dim": "#9aa1a9",
        "colors.accent": "#0969da", "colors.warning": "#bf8700", "colors.error": "#cf222e"
    })

    function resetList() {
        switch (tabId) {
        case "bar": return [["shell", "bar.position"], ["shell", "bar.modules"], ["theme", "layout.barHeight"], ["theme", "layout.barRadius"], ["theme", "font.barSize"], ["theme", "barOpacity"]];
        case "weather": return [["shell", "weather.latitude"], ["shell", "weather.longitude"], ["shell", "weather.placeName"], ["shell", "weather.units"]];
        case "outputs": return [["sway", "outputs"]];
        case "input": return [["sway", "input"]];
        case "wallpaper": return [["sway", "wallpaper"]];
        case "keys": return [["sway", "keybindings"]];
        case "autostart": return [["sway", "autostart"]];
        case "rules": return [["sway", "rules"]];
        case "gaps": return [["sway", "gaps"]];
        default: return [["theme", "colors"], ["theme", "font.family"], ["theme", "font.size"], ["theme", "layout.radius"]];
        }
    }

    function activate(r) {
        if (!r) return;
        if (r.kind === "color" || r.kind === "text" || r.kind === "search") { startEdit(r); return; }
        if (r.kind === "bind") { editBind(r); return; }
        if (r.kind === "auto") { editAuto(r); return; }
        if (r.kind === "rule") { editRule(r); return; }
        if (r.kind === "place") {
            Settings.setMany("shell", { "weather.latitude": r.place.lat, "weather.longitude": r.place.lon, "weather.placeName": r.place.name });
            Geocoding.clear();
            return;
        }
        if (r.kind === "number" || r.kind === "choice") { step(r, 1); return; }
        if (r.kind !== "action") return;
        if (r.act === "presetDark") Settings.resetMany([["theme", "colors"]]);
        else if (r.act === "presetLight") Settings.setMany("theme", light);
        else if (r.act === "resetModules") Settings.resetMany([["shell", "bar.modules"]]);
        else if (r.act === "resetTab") confirmReset = true;
        else if (r.act === "openHome") Quickshell.execDetached(["xdg-open", homeUrl]);
        else if (r.act === "openReleases") Quickshell.execDetached(["xdg-open", homeUrl + "/releases"]);
        else if (r.act === "addBind") addBind();
        else if (r.act === "addAuto") addAuto();
        else if (r.act === "addRule") addRule();
        else if (r.act === "keepOutputs") SwayBackend.confirm();
        else if (r.act === "revertOutputs") SwayBackend.revert();
        else if (r.act === "addInclude")
            pendingConfirm = { text: "Aggiungere la riga include a " + SwayBackend.swayConfigPath + " (copia: config.bak-vela-include)? Invio = sì, Esc = no",
                               fn: function () { SwayBackend.addInclude(); } };
    }

    function startEdit(r) {
        editing = r;
        note = "";
        editor.begin(r.kind === "search" ? "" : String(r.value));
        field.forceActiveFocus();
        field.selectAll();
    }
    function submitEdit() {
        if (editing && editing.kind === "steps") { stepSubmit(); return; }
        var r = editing, t = field.text.trim();
        if (r.kind === "color") {
            if (/^[0-9a-fA-F]{6}$/.test(t)) t = "#" + t;
            if (!/^#[0-9a-fA-F]{6}$/.test(t)) { note = "Colore non valido: usare #rrggbb"; return; }
            t = t.toLowerCase();
        } else if (r.file === "sway") {
            if (t === "") { Settings.reset(r.file, r.path); cancelEdit(); return; }       // vuoto = predefinito
            if (r.path === "wallpaper.path") t = t.replace(/^~\//, Quickshell.env("HOME") + "/");
            if (!SwayBackend.safe(t)) { note = "Caratteri non ammessi (niente virgolette, $ o ;)"; return; }
        } else if (t === "") { note = "Valore vuoto"; return; }
        if (r.kind === "search") { Geocoding.search(t); cancelEdit(); return; }
        Settings.set(r.file, r.path, t);
        cancelEdit();
    }
    function cancelEdit() { editing = null; note = ""; keys.forceActiveFocus(); }

    function resetRow(r) {
        if (r && r.kind === "bind") { removeBind(r.combo); return; }
        if (r && r.kind === "auto") { removeAt("autostart", r.idx); return; }
        if (r && r.kind === "rule") { removeAt("rules", r.idx); return; }
        if (r && r.kind === "search") Settings.resetMany([["shell", "weather.latitude"], ["shell", "weather.longitude"], ["shell", "weather.placeName"]]);
        else if (r && r.file && r.over) Settings.reset(r.file, r.path);
        else if (r && r.kind === "module") Settings.resetMany([["shell", "bar.modules"]]);
    }

    onOpenChanged: {
        if (open) {
            editing = null; confirmReset = false; pendingConfirm = null; note = "";
            SwayBackend.refresh();
            Qt.callLater(function () { list.positionViewAtBeginning(); });
            for (var i = 0; i < rows.length; i++) if (selectable(rows[i])) { select(i); break; }
            keys.forceActiveFocus();
        }
    }

    // --- aspetto ------------------------------------------------------------------------
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 60); i++) h += rows[i].kind === "header" ? sectionHeight : Theme.rowHeight;
        return Math.min(h, maxRows * Theme.rowHeight + 3 * sectionHeight);
    }
    contentHeight: headerHeight + 1 + (editing ? Theme.rowHeight * 2 + Theme.padding : listHeight + Theme.padding) + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            var shift = event.modifiers & Qt.ShiftModifier;
            var r = panel.current();
            if (event.key === Qt.Key_Escape) {
                if (panel.confirmReset) panel.confirmReset = false;
                else if (panel.pendingConfirm) panel.pendingConfirm = null;
                else Runtime.closePanel();
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                panel.tab = (panel.tab + 1) % panel.tabNames.length;
            } else if (shift && event.key === Qt.Key_Up) {
                if (r && r.kind === "module") panel.reorder(r, -1);
            } else if (shift && event.key === Qt.Key_Down) {
                if (r && r.kind === "module") panel.reorder(r, 1);
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Right) {
                if (r) panel.step(r, 1);
            } else if (event.key === Qt.Key_Left) {
                if (r) panel.step(r, -1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (panel.confirmReset) { Settings.resetMany(panel.resetList()); panel.confirmReset = false; }
                else if (panel.pendingConfirm) { var pc = panel.pendingConfirm; panel.pendingConfirm = null; pc.fn(); }
                else panel.activate(r);
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                panel.resetRow(r);
            } else {
                return;
            }
            event.accepted = true;
        }

        // Categorie (a sinistra, come nelle impostazioni di GNOME)
        Rectangle {
            id: sidebar
            width: panel.sidebarWidth
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            color: Qt.alpha(Theme.background, 0.5)
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
            BarText {
                anchors { left: parent.left; leftMargin: Theme.padding; top: parent.top; topMargin: Theme.padding }
                text: "Impostazioni"
                font.bold: true
            }
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: Theme.rowHeight + Theme.padding }
                Repeater {
                    model: panel.tabNames
                    delegate: Item {
                        required property string modelData
                        required property int index
                        width: parent.width
                        height: Theme.rowHeight
                        PanelRow {
                            anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                            selected: index === panel.tab
                            title: modelData
                            bold: index === panel.tab
                            onClicked: panel.tab = index
                        }
                    }
                }
            }
        }

        Item {
            id: content
            anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        // Intestazione con le schede
        Item {
            id: head
            width: parent.width
            height: panel.headerHeight
            BarText {
                anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: panel.tabNames[panel.tab]
                font.bold: true
            }
        }
        Rectangle { id: sepLine; anchors.top: head.bottom; width: parent.width; height: 1; color: Theme.border }

        // Modifica di un colore (con selettore visuale) o di un testo
        Item {
            id: editor
            visible: panel.editing !== null
            readonly property bool isColor: panel.editing !== null && panel.editing.kind === "color"
            readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(field.text.trim())
            property real hue: 0
            property real sat: 0
            property real val: 0
            property bool pushing: false      // il testo lo ha scritto il selettore: non rileggerlo
            anchors { top: sepLine.bottom; left: parent.left; right: parent.right; margins: Theme.padding }
            height: isColor ? Theme.rowHeight * 2 + 300 : Theme.rowHeight * 2

            readonly property var palette: ["#1a1a1a", "#4a4c52", "#7e8087", "#e4e5e6", "#ffffff", "#c6262e", "#f5a623", "#ffd400",
                                            "#68b723", "#00a6a6", "#3689e6", "#9a47d6", "#ff5500", "#ff79c6", "#8be9fd", "#000000"]

            function load(t) {
                t = t.trim();
                if (!/^#[0-9a-fA-F]{6}$/.test(t)) return;
                var c = Qt.color(t);
                hue = Math.max(0, c.hsvHue); sat = c.hsvSaturation; val = c.hsvValue;
            }
            function push() {
                pushing = true;
                field.text = Qt.hsva(hue, sat, val, 1).toString();
                pushing = false;
            }
            function begin(t) { field.text = t; load(t); }

            BarText {
                id: editLabel
                width: parent.width
                text: panel.editing ? (panel.editing.kind === "search" ? "Nome della città" : panel.editing.label) : ""
                elide: Text.ElideRight
                color: Theme.muted
            }
            Rectangle {
                id: inputBox
                anchors { top: editLabel.bottom; topMargin: Theme.spacing / 2; left: parent.left; right: editor.isColor ? swatch.left : parent.right; rightMargin: editor.isColor ? Theme.spacing : 0 }
                height: Theme.rowHeight - 4
                color: Theme.background
                border.color: Theme.accent
                radius: Theme.radius
                TextInput {
                    id: field
                    enabled: panel.editing !== null     // da disabilitato non tiene il focus
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize
                    selectByMouse: true
                    clip: true
                    onTextChanged: if (editor.isColor && !editor.pushing) editor.load(text)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.submitEdit();
                        else if (event.key === Qt.Key_Escape) panel.cancelEdit();
                        else return;
                        event.accepted = true;
                    }
                }
            }
            // anteprima del colore digitato
            Rectangle {
                id: swatch
                visible: editor.isColor
                width: Theme.rowHeight - 4; height: width
                radius: Theme.radius
                anchors { right: parent.right; top: inputBox.top }
                color: editor.valid ? field.text.trim() : "transparent"
                border.color: Theme.dim
            }

            // selettore: quadrato saturazione/luminosità, barra del tono, tavolozza
            Item {
                visible: editor.isColor
                anchors { top: inputBox.bottom; topMargin: Theme.padding; left: parent.left; right: parent.right }
                height: 230

                Rectangle {
                    id: sv
                    width: 300; height: 220
                    color: Qt.hsva(editor.hue, 1, 1, 1)
                    border.color: Theme.border
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#ffffffff" }
                            GradientStop { position: 1; color: "#00ffffff" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#00000000" }
                            GradientStop { position: 1; color: "#ff000000" }
                        }
                    }
                    Rectangle {
                        x: editor.sat * sv.width - width / 2
                        y: (1 - editor.val) * sv.height - height / 2
                        width: 14; height: 14; radius: 7
                        color: "transparent"
                        border.width: 2
                        border.color: editor.val > 0.5 && editor.sat < 0.5 ? "#000000" : "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent
                        function pick(m) {
                            editor.sat = Math.max(0, Math.min(1, m.x / width));
                            editor.val = 1 - Math.max(0, Math.min(1, m.y / height));
                            editor.push();
                        }
                        onPressed: m => pick(m)
                        onPositionChanged: m => { if (pressed) pick(m); }
                    }
                }
                Rectangle {
                    id: hueBar
                    anchors { left: sv.right; leftMargin: Theme.padding; top: sv.top }
                    width: 22; height: sv.height
                    border.color: Theme.border
                    gradient: Gradient {
                        GradientStop { position: 0.000; color: "#ff0000" }
                        GradientStop { position: 0.167; color: "#ffff00" }
                        GradientStop { position: 0.333; color: "#00ff00" }
                        GradientStop { position: 0.500; color: "#00ffff" }
                        GradientStop { position: 0.667; color: "#0000ff" }
                        GradientStop { position: 0.833; color: "#ff00ff" }
                        GradientStop { position: 1.000; color: "#ff0000" }
                    }
                    Rectangle {
                        width: parent.width + 4; height: 4
                        x: -2
                        y: editor.hue * hueBar.height - 2
                        color: "#ffffff"
                        border.color: "#000000"
                    }
                    MouseArea {
                        anchors.fill: parent
                        function pick(m) {
                            editor.hue = Math.max(0, Math.min(0.999, m.y / height));
                            editor.push();
                        }
                        onPressed: m => pick(m)
                        onPositionChanged: m => { if (pressed) pick(m); }
                    }
                }
                // tavolozza di colori pronti
                Grid {
                    anchors { left: hueBar.right; leftMargin: Theme.padding; top: sv.top }
                    columns: 4
                    spacing: Theme.gap + 2
                    Repeater {
                        model: editor.palette
                        delegate: Rectangle {
                            required property string modelData
                            width: 28; height: 28
                            radius: 3
                            color: modelData
                            border.color: Theme.dim
                            TapHandler { onTapped: editor.begin(parent.modelData) }
                        }
                    }
                }
                // pulsanti
                Row {
                    anchors { left: hueBar.right; leftMargin: Theme.padding; bottom: sv.bottom }
                    spacing: Theme.spacing
                    Rectangle {
                        width: applyLabel.implicitWidth + Theme.padding * 2; height: Theme.rowHeight - 6
                        radius: Theme.radius
                        color: Theme.accent
                        BarText { id: applyLabel; anchors.centerIn: parent; text: "Applica"; color: Theme.background }
                        TapHandler { onTapped: panel.submitEdit() }
                    }
                    Rectangle {
                        width: cancelLabel.implicitWidth + Theme.padding * 2; height: Theme.rowHeight - 6
                        radius: Theme.radius
                        color: Theme.border
                        BarText { id: cancelLabel; anchors.centerIn: parent; text: "Annulla" }
                        TapHandler { onTapped: panel.cancelEdit() }
                    }
                }
            }
        }

        // Elenco
        ListView {
            id: list
            visible: panel.editing === null
            anchors { top: sepLine.bottom; topMargin: Theme.padding / 2; left: parent.left; right: parent.right }
            height: parent.height - head.height - 1 - panel.footerHeight - Theme.padding
            model: panel.rows
            clip: true
            currentIndex: -1
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                readonly property var r: modelData
                readonly property bool isHeader: modelData && modelData.kind === "header"
                readonly property bool isInfo: modelData && modelData.kind === "info"
                width: ListView.view.width
                height: isHeader ? 28 : (modelData && modelData.kind === "logo") ? 190 : Theme.rowHeight

                PanelSectionHeader { visible: entry.isHeader; text: entry.isHeader ? entry.r.label : "" }

                // logo e nome del progetto (pagina Informazioni)
                Column {
                    visible: entry.r.kind === "logo"
                    anchors.centerIn: parent
                    spacing: Theme.spacing
                    VelaLogo { size: 96; anchors.horizontalCenter: parent.horizontalCenter }
                    BarText { text: "Vela"; font.bold: true; font.pixelSize: Theme.fontSize + 8; anchors.horizontalCenter: parent.horizontalCenter }
                    BarText { text: "Shell desktop per Sway su Void Linux"; color: Theme.muted; anchors.horizontalCenter: parent.horizontalCenter }
                }

                Component {
                    id: swatchComp
                    Rectangle {
                        width: 14; height: 14
                        radius: 2
                        color: entry.r && entry.r.kind === "color" ? entry.r.value : "transparent"
                        border.color: Theme.dim
                    }
                }

                // impostazione (numero, scelta, colore, testo, elemento, azione, informazione)
                PanelRow {
                    visible: !entry.isHeader && entry.r.kind !== "logo"
                    enabled: !entry.isInfo
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem && panel.selectable(entry.r)
                    selected: entry.r.over === true        // il valore è stato impostato dal pannello
                    title: entry.isHeader ? "" : (entry.r.kind === "module" ? entry.r.name : entry.r.label)
                    titleColor: entry.r.kind === "action" ? Theme.accent : Theme.foreground
                    trailingText: entry.isHeader || entry.r.kind === "action" ? ""
                        : (entry.r.kind === "number" || entry.r.kind === "choice" ? "‹ " + entry.r.text + " ›" : entry.r.text)
                    trailingColor: entry.isHeader ? Theme.muted
                        : entry.r.kind === "module" && entry.r.zone === "hidden" ? Theme.dim
                        : entry.r.kind === "info" && entry.r.tone === "accent" ? Theme.accent
                        : entry.r.kind === "info" && entry.r.tone === "warn" ? Theme.warning
                        : Theme.muted
                    trailing: entry.r.kind === "color" ? swatchComp : null
                    onMoved: if (panel.selectable(entry.r)) panel.select(entry.index)
                    onClicked: if (panel.selectable(entry.r)) { panel.select(entry.index); panel.activate(entry.r); }
                }
            }
        }

        // Suggerimenti / conferma
        Rectangle {
            id: foot
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: panel.footerHeight
            color: "transparent"
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
            BarText {
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize - 2
                color: panel.confirmReset || panel.pendingConfirm || panel.note !== "" ? Theme.warning : Theme.dim
                text: {
                    if (panel.note !== "") return panel.note;
                    if (panel.confirmReset) return "Ripristinare questa scheda? Invio = sì, Esc = no";
                    if (panel.pendingConfirm) return panel.pendingConfirm.text;
                    if (panel.editing) return "Invio = applica · Esc = annulla";
                    var r = panel.current();
                    if (panel.tabId === "compositor" && !(panel.current() && panel.current().kind === "action")) return "Informazioni sul compositor · Tab categoria · Esc chiudi";
                    if (r && r.kind === "bind") return "Invio = cambia il comando · Canc " + (r.own ? "rimuove" : "toglie la sostituzione") + " · Tab categoria";
                    if (r && (r.kind === "auto" || r.kind === "rule")) return "Invio = modifica · Canc rimuove · Tab categoria";
                    if (r && r.kind === "search") return "Invio = cerca una città · Canc ripristina · Tab categoria";
                    if (r && r.kind === "place") return "Invio = scegli questa città · Tab categoria";
                    if (r && r.kind === "module") return "←/→ zona · Maiusc+↑/↓ ordine · Canc ripristina · Tab scheda";
                    if (r && (r.kind === "number" || r.kind === "choice")) return "←/→ cambia · Canc ripristina · Tab scheda · Esc chiudi";
                    if (r && (r.kind === "color" || r.kind === "text")) return "Invio = modifica · Canc ripristina · Tab scheda";
                    return "Invio = applica · Tab scheda · Esc chiudi";
                }
            }
        }
        }
    }
}
