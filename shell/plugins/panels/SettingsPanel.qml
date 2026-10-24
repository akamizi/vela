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
        var t = [{ id: "bar", label: I18n.tr("Barra") }, { id: "theme", label: I18n.tr("Tema") }, { id: "weather", label: I18n.tr("Meteo") },
                 { id: "idle", label: I18n.tr("Blocco e inattività") }, { id: "apps", label: I18n.tr("App predefinite") }, { id: "radio", label: I18n.tr("Radio") }];
        if (Compositors.activeHasBackend && SwayBackend.active) {
            t.push({ id: "outputs", label: I18n.tr("Schermi") }, { id: "input", label: I18n.tr("Tastiera e touchpad") }, { id: "wallpaper", label: I18n.tr("Sfondo") },
                   { id: "keys", label: I18n.tr("Scorciatoie") }, { id: "autostart", label: I18n.tr("Avvio automatico") },
                   { id: "rules", label: I18n.tr("Regole delle finestre") }, { id: "gaps", label: I18n.tr("Bordi e spazi") });
        }
        else if (Compositors.activeId === "labwc") t.push({ id: "outputs", label: I18n.tr("Schermi") });     // labwc: solo gli schermi (wlr-randr)
        if (BatteryLimit.supported) t.push({ id: "battery", label: I18n.tr("Batteria") });
        t.push({ id: "compositor", label: I18n.tr("Compositor") }, { id: "about", label: I18n.tr("Informazioni") });
        return t;
    }
    readonly property var tabNames: tabs.map(function (t) { return t.label; })
    readonly property string tabId: (tabs[tab] || tabs[0]).id
    property bool picking: false              // selettore grafico dello sfondo aperto
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
                 value: unset ? (fallback !== undefined ? fallback : min) : v, text: unset ? I18n.tr("predefinito") : fmt(v, dec),
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
        var v = Settings.get(file, path), t = (v === null || v === undefined) ? I18n.tr("predefinito") : String(v);
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
        return { kind: "text", file: file, path: path, label: label, value: unset ? "" : v, text: unset ? I18n.tr("predefinito") : v,
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function header(label) { return { kind: "header", label: label, key: "h:" + label }; }

    readonly property var zoneOrder: ["left", "center", "right", "hidden"]
    readonly property var zoneLabels: ({ left: I18n.tr("Sinistra"), center: I18n.tr("Centro"), right: I18n.tr("Destra"), hidden: I18n.tr("Nascosto") })

    function barRows() {
        var out = [header(I18n.tr("Aspetto"))];
        out.push(choice("shell", "bar.position", I18n.tr("Posizione"), [{ v: "top", t: I18n.tr("in alto") }, { v: "bottom", t: I18n.tr("in basso") }]));
        out.push(number("theme", "layout.barHeight", I18n.tr("Altezza"), 18, 48, 2, 0));
        out.push(number("theme", "font.barSize", I18n.tr("Dimensione del testo nella barra"), 9, 22, 1, 0));
        out.push(number("theme", "layout.barRadius", I18n.tr("Angoli della barra"), 0, 16, 1, 0));
        out.push(number("theme", "barOpacity", I18n.tr("Trasparenza dello sfondo (opacità)"), 0, 1, 0.05, 2));
        out.push(header(I18n.tr("Elementi")));
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
        out.push({ kind: "action", label: I18n.tr("Ripristina gli elementi di default"), act: "resetModules", key: "a:resetModules" });
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function themeRows() {
        var out = [header(I18n.tr("Preset"))];
        out.push({ kind: "action", label: I18n.tr("Scuro (predefinito)"), act: "presetDark", key: "a:dark" });
        out.push({ kind: "action", label: I18n.tr("Chiaro"), act: "presetLight", key: "a:light" });
        out.push(header(I18n.tr("Colori")));
        var names = [["background", I18n.tr("Sfondo")], ["surface", I18n.tr("Superficie")], ["border", I18n.tr("Bordo")], ["foreground", I18n.tr("Testo")],
                     ["muted", I18n.tr("Testo attenuato")], ["dim", I18n.tr("Testo debole")], ["accent", I18n.tr("Accento")],
                     ["warning", I18n.tr("Avviso")], ["error", I18n.tr("Errore")]];
        names.forEach(function (n) { out.push(color("theme", "colors." + n[0], n[1])); });
        out.push(header(I18n.tr("Carattere e forma")));
        out.push(textRow("theme", "font.family", I18n.tr("Carattere")));
        out.push(number("theme", "font.size", I18n.tr("Dimensione del testo (pannelli, menu, notifiche)"), 9, 22, 1, 0));
        out.push(number("theme", "layout.radius", I18n.tr("Angoli di pannelli, menu e notifiche"), 0, 16, 1, 0));
        out.push(header(I18n.tr("App Qt (vela theme qt)")));
        out.push(textRow("theme", "qt.iconTheme", I18n.tr("Tema delle icone (cartella in ~/.local/share/icons o /usr/share/icons)")));
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function weatherRows() {
        var w = Config.shell.weather;
        var out = [header(I18n.tr("Meteo"))];
        var on = typeof w.latitude === "number" && typeof w.longitude === "number";
        out.push(info(I18n.tr("Stato"), on ? I18n.tr("attivo") : I18n.tr("spento: scegli una città"), on ? "accent" : "warn"));
        out.push({ kind: "search", label: I18n.tr("Città"), text: w.placeName ? w.placeName : (on ? "coordinate impostate" : "non impostata"),
                   over: Settings.overridden("shell", "weather.placeName"), key: "search:city" });
        out.push(choice("shell", "weather.units", I18n.tr("Unità di misura"), [{ v: "metric", t: I18n.tr("metriche (°C)") }, { v: "imperial", t: I18n.tr("imperiali (°F)") }]));
        if (Geocoding.busy) out.push(info(I18n.tr("Ricerca di «%1»", Geocoding.query), I18n.tr("in corso…")));
        else if (Geocoding.error !== "") out.push(info(I18n.tr("Ricerca di «%1»", Geocoding.query), Geocoding.error, "warn"));
        if (Geocoding.results.length > 0) {
            out.push(header(I18n.tr("Risultati per «%1»", Geocoding.query)));
            Geocoding.results.forEach(function (r, i) {
                out.push({ kind: "place", label: r.label, text: r.lat.toFixed(2) + ", " + r.lon.toFixed(2), place: r, key: "place:" + i });
            });
        }
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    // --- schermi, tastiera, touchpad, sfondo (backend Sway) -------------------------------------
    property var pendingConfirm: null     // {text, fn}: conferma generica (es. modifica del config di Sway)

    function uniq(a) { var seen = {}, out = []; a.forEach(function (x) { if (!seen[x]) { seen[x] = true; out.push(x); } }); return out; }

    function outputsRows() {
        var out = [];
        if (SwayBackend.pending) {
            out.push(header(I18n.tr("Conferma")));
            out.push(info(I18n.tr("Mantenere queste impostazioni?"), I18n.tr("tra %1 s si torna indietro", SwayBackend.countdown), "warn"));
            out.push({ kind: "action", label: I18n.tr("Mantieni"), act: "keepOutputs", key: "a:keep" });
            out.push({ kind: "action", label: I18n.tr("Ripristina ora"), act: "revertOutputs", key: "a:revert" });
        }
        var outs = SwayBackend.outputs, activeCount = outs.filter(function (o) { return o.active; }).length;
        outs.forEach(function (o) {
            var n = o.name, k = "o:" + n + ":";
            out.push(header(n + (o.label ? " — " + o.label : "")));
            if (o.active) {
                out.push(choiceC(k + "mode", I18n.tr("Risoluzione e frequenza"), uniq(o.modes).map(function (m) { return { v: m, t: m }; }), o.mode,
                                 function (v) { SwayBackend.setOutput(n, { mode: v }); }));
                out.push(numberC(k + "scale", I18n.tr("Scala"), 0.5, 3, 0.25, 2, o.scale, function (v) { SwayBackend.setOutput(n, { scale: v }); }));
                out.push(choiceC(k + "transform", I18n.tr("Rotazione"), [{ v: "normal", t: I18n.tr("normale") }, { v: "90", t: "90°" }, { v: "180", t: "180°" }, { v: "270", t: "270°" }],
                                 o.transform, function (v) { SwayBackend.setOutput(n, { transform: v }); }));
                if (outs.length > 1) {
                    out.push(numberC(k + "x", I18n.tr("Posizione orizzontale"), -10000, 20000, 10, 0, o.x, function (v) { SwayBackend.setOutput(n, { x: v }); }));
                    out.push(numberC(k + "y", I18n.tr("Posizione verticale"), -10000, 20000, 10, 0, o.y, function (v) { SwayBackend.setOutput(n, { y: v }); }));
                }
            }
            // Con un solo schermo acceso non si può spegnere.
            if (outs.length > 1 && (!o.active || activeCount > 1))
                out.push(choiceC(k + "enabled", I18n.tr("Schermo"), [{ v: true, t: I18n.tr("acceso") }, { v: false, t: I18n.tr("spento") }], o.active,
                                 function (v) { SwayBackend.setOutput(n, { enabled: v }); }));
        });
        if (outs.length === 0) out.push(info(I18n.tr("Schermi"), I18n.tr("nessuno rilevato"), "warn"));
        if (SwayBackend.lastError !== "") out.push(info(I18n.tr("Errore di Sway"), SwayBackend.lastError, "warn"));
        out.push(header(I18n.tr("Scelte salvate")));
        out.push({ kind: "action", label: I18n.tr("Dimentica le impostazioni salvate degli schermi"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    readonly property var onOff: [{ v: "enabled", t: I18n.tr("sì") }, { v: "disabled", t: I18n.tr("no") }]

    function inputRows() {
        var out = [header(I18n.tr("Tastiera"))];
        out.push(textRow("sway", "input.keyboard.layout", I18n.tr("Layout (es. it oppure it,us)")));
        out.push(textRow("sway", "input.keyboard.variant", I18n.tr("Variante")));
        out.push(textRow("sway", "input.keyboard.options", I18n.tr("Opzioni (es. grp:alt_shift_toggle)")));
        out.push(number("sway", "input.keyboard.repeatDelay", I18n.tr("Ritardo di ripetizione (ms)"), 100, 1000, 50, 0, 600));
        out.push(number("sway", "input.keyboard.repeatRate", I18n.tr("Ripetizioni al secondo"), 5, 60, 1, 0, 25));
        out.push(header(I18n.tr("Touchpad")));
        if (SwayBackend.hasTouchpad) {
            out.push(choice("sway", "input.touchpad.tap", I18n.tr("Tocco per cliccare"), onOff));
            out.push(choice("sway", "input.touchpad.naturalScroll", I18n.tr("Scorrimento naturale"), onOff));
            out.push(choice("sway", "input.touchpad.disableWhileTyping", I18n.tr("Disattiva mentre si scrive"), onOff));
            out.push(number("sway", "input.touchpad.accel", I18n.tr("Velocità del puntatore"), -1, 1, 0.1, 1, 0));
        } else {
            out.push(info(I18n.tr("Touchpad"), I18n.tr("nessuno rilevato")));
        }
        if (SwayBackend.lastError !== "") out.push(info(I18n.tr("Errore di Sway"), SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function wallpaperRows() {
        var out = [header(I18n.tr("Sfondo"))];
        out.push({ kind: "action", label: I18n.tr("Scegli un'immagine…"), act: "pickWallpaper", key: "a:pickwp" });
        out.push(textRow("sway", "wallpaper.path", I18n.tr("Immagine (percorso)")));
        out.push(choice("sway", "wallpaper.mode", I18n.tr("Adattamento"), [{ v: "fill", t: "riempi" }, { v: "fit", t: "adatta" }, { v: "stretch", t: "allunga" },
                                                                 { v: "center", t: "centra" }, { v: "tile", t: "affianca" }]));
        out.push(color("sway", "wallpaper.color", I18n.tr("Colore (senza immagine)")));
        if (SwayBackend.lastError !== "") out.push(info(I18n.tr("Errore di Sway"), SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function persistenceRows() {
        var out = [header(I18n.tr("Persistenza al login (Sway)"))];
        out.push(info(I18n.tr("File generato da Vela"), SwayBackend.confPath));
        if (SwayBackend.hasInclude) {
            out.push(info(I18n.tr("include nel config di Sway"), I18n.tr("presente"), "accent"));
        } else {
            out.push(info(I18n.tr("include nel config di Sway"), I18n.tr("mancante: gli schermi non si ricordano al login"), "warn"));
            out.push({ kind: "action", label: I18n.tr("Aggiungi la riga include al config di Sway (con copia di sicurezza)"), act: "addInclude", key: "a:include" });
        }
        return out;
    }

    // --- scorciatoie, avvio automatico, regole, bordi e spazi (Sway) ---------------------------------
    function list(name) { return (Config.sway[name] || []).slice(); }
    function setList(name, arr) { Settings.set("sway", name, arr); }

    function keysRows() {
        var out = [header(I18n.tr("Scorciatoie di Vela"))];
        var mine = Config.sway.keybindings;
        mine.forEach(function (b) {
            out.push({ kind: "bind", own: true, combo: b.combo, command: b.command, label: b.combo,
                       text: b.command ? b.command : I18n.tr("disattivata"), key: "kb:" + b.combo });
        });
        if (mine.length === 0) out.push(info(I18n.tr("Nessuna"), I18n.tr("aggiungine una o cambia una del config di Sway")));
        out.push({ kind: "action", label: I18n.tr("Aggiungi una scorciatoia"), act: "addBind", key: "a:addbind" });
        var theirs = SwayBackend.userConfig.binds;
        out.push(header(I18n.tr("Dal config di Sway (la tua scelta sostituisce quella del config)")));
        var vars = SwayBackend.userConfig.vars;
        theirs.forEach(function (b) {
            var n = SwayConf.normalize(b.combo, vars);
            var over = mine.some(function (m) { return SwayConf.normalize(m.combo, vars) === n; });
            out.push({ kind: "bind", own: false, combo: b.combo, command: b.command, label: b.combo,
                       text: (over ? I18n.tr("sostituita") + " · " : "") + b.command, over: over, key: "ub:" + b.combo });
        });
        if (theirs.length === 0) out.push(info(I18n.tr("Config di Sway"), I18n.tr("nessuna scorciatoia trovata")));
        if (SwayBackend.lastError !== "") out.push(info(I18n.tr("Errore di Sway"), SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    // --- radio: le stazioni stanno in shell.radio.stations; alla prima modifica la lista attuale (anche quella
    // scritta a mano in shell.jsonc) viene copiata in settings.jsonc, che ha la precedenza.
    function stations() { return (Config.shell.radio.stations || []).map(function (s) { return { name: s.name, url: s.url }; }); }
    function setStations(a) { Settings.set("shell", "radio.stations", a); }
    function radioRows() {
        var out = [header(I18n.tr("Stazioni"))];
        stations().forEach(function (st, i) { out.push({ kind: "station", idx: i, label: st.name, text: st.url, key: "rs:" + st.url }); });
        if (Config.shell.radio.stations.length === 0) out.push(info(I18n.tr("Nessuna"), I18n.tr("aggiungine una")));
        out.push({ kind: "action", label: I18n.tr("Aggiungi una stazione"), act: "addStation", key: "a:addstation" });
        out.push(info(I18n.tr("Ordine"), I18n.tr("Maiusc+↑/↓ sposta la stazione selezionata")));
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }
    function urlProblem(t) { return Radio.validUrl(t) ? "" : I18n.tr("Indirizzo non valido: deve iniziare con http:// o https://"); }
    function addStation() {
        startSteps([
            { label: I18n.tr("Nome della stazione") },
            { label: function (a) { return I18n.tr("Indirizzo del flusso di %1 (http://…)", a[0]); }, validate: urlProblem }
        ], function (a) { var l = stations(); l.push({ name: a[0], url: a[1] }); setStations(l); });
    }
    function editStation(r) {
        var st = stations()[r.idx];
        if (!st) return;
        startSteps([
            { label: I18n.tr("Nome della stazione"), initial: st.name },
            { label: I18n.tr("Indirizzo del flusso"), initial: st.url, validate: urlProblem }
        ], function (a) { var l = stations(); l[r.idx] = { name: a[0], url: a[1] }; setStations(l); });
    }
    function moveStation(r, dir) {
        var l = stations(), j = r.idx + dir;
        if (j < 0 || j >= l.length) return;
        var t = l[r.idx]; l[r.idx] = l[j]; l[j] = t;
        setStations(l);
    }

    function autostartRows() {
        var out = [header(I18n.tr("Avviati da Vela"))];
        Config.sway.autostart.forEach(function (c, i) { out.push({ kind: "auto", idx: i, label: c, text: "", key: "au:" + i + ":" + c }); });
        if (Config.sway.autostart.length === 0) out.push(info(I18n.tr("Nessuno"), I18n.tr("aggiungine uno")));
        out.push({ kind: "action", label: I18n.tr("Aggiungi un programma"), act: "addAuto", key: "a:addauto" });
        if (!SwayBackend.hasInclude) out.push(info(I18n.tr("Attenzione"), I18n.tr("serve l'include nel config di Sway (categoria Compositor)"), "warn"));
        out.push(header(I18n.tr("Dal config di Sway (sola lettura)")));
        SwayBackend.userConfig.execs.forEach(function (e, i) { out.push(info(e.command, e.always ? I18n.tr("a ogni reload") : I18n.tr("all'avvio"))); });
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function rulesRows() {
        var out = [header(I18n.tr("Regole di Vela"))];
        Config.sway.rules.forEach(function (rl, i) { out.push({ kind: "rule", idx: i, label: rl.criteria, text: rl.command, key: "ru:" + i + ":" + rl.criteria }); });
        if (Config.sway.rules.length === 0) out.push(info(I18n.tr("Nessuna"), I18n.tr("aggiungine una (es. [app_id=\"foot\"] floating enable)")));
        out.push({ kind: "action", label: I18n.tr("Aggiungi una regola"), act: "addRule", key: "a:addrule" });
        out.push(header(I18n.tr("Dal config di Sway (sola lettura)")));
        SwayBackend.userConfig.rules.forEach(function (rl) { out.push(info(rl.criteria, rl.command)); });
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function gapsRows() {
        var out = [header(I18n.tr("Finestre"))];
        out.push(number("sway", "gaps.inner", I18n.tr("Spazio tra le finestre (px)"), 0, 50, 1, 0, 0));
        out.push(number("sway", "gaps.outer", I18n.tr("Spazio dal bordo dello schermo (px)"), 0, 50, 1, 0, 0));
        out.push(number("sway", "gaps.border", I18n.tr("Spessore del bordo (px, finestre nuove)"), 0, 10, 1, 0, 1));
        out.push(choice("sway", "gaps.smartGaps", I18n.tr("Niente spazi con una sola finestra"), [{ v: "on", t: I18n.tr("sì") }, { v: "off", t: I18n.tr("no") }, { v: "inverse_outer", t: I18n.tr("solo esterni") }]));
        out.push(choice("sway", "gaps.smartBorders", I18n.tr("Niente bordi con una sola finestra"), [{ v: "on", t: I18n.tr("sì") }, { v: "off", t: I18n.tr("no") }, { v: "no_gaps", t: I18n.tr("solo senza spazi") }]));
        if (SwayBackend.lastError !== "") out.push(info(I18n.tr("Errore di Sway"), SwayBackend.lastError, "warn"));
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
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
        if (t === "" && !st.allowEmpty) { note = I18n.tr("Valore vuoto"); return; }
        if (t !== "" && !SwayBackend.oneLine(t)) { note = I18n.tr("Solo una riga, senza caratteri di controllo"); return; }
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
        startSteps([{ label: I18n.tr("Comando per %1 (vuoto = disattiva)", r.combo), initial: r.own ? (r.command || "") : r.command, allowEmpty: true }],
                   function (a) { upsertBind(r.combo, a[0]); });
    }
    function addBind() {
        startSteps([
            { label: I18n.tr("Combinazione (es. $mod+Shift+e)"), validate: function (t) { return /^[A-Za-z0-9_$+\-]+$/.test(t) ? "" : I18n.tr("Combinazione non valida: usare nomi come $mod+Shift+e"); },
              after: function (a) {
                  var c = SwayBackend.conflictFor(a[0], "");
                  return c ? I18n.tr("Attenzione: «%1» è già assegnata a «%2» (%3): sarà sostituita", a[0], c.command, c.source === "sway" ? I18n.tr("config di Sway") : "Vela") : "";
              } },
            { label: function (a) { return I18n.tr("Comando per %1 (es. exec foot)", a[0]); } }
        ], function (a) { upsertBind(a[0], a[1]); });
    }
    function addAuto() { startSteps([{ label: I18n.tr("Programma da avviare (es. nm-applet --indicator)") }], function (a) { var l = list("autostart"); l.push(a[0]); setList("autostart", l); }); }
    function editAuto(r) { startSteps([{ label: I18n.tr("Programma da avviare"), initial: r.label }], function (a) { var l = list("autostart"); l[r.idx] = a[0]; setList("autostart", l); }); }
    function addRule() {
        startSteps([
            { label: I18n.tr("Criteri (es. app_id=\"foot\")") },
            { label: function (a) { return I18n.tr("Comando per [%1] (es. floating enable)", a[0].replace(/^\[|\]$/g, "")); } }
        ], function (a) { var l = list("rules"); l.push({ criteria: a[0], command: a[1] }); setList("rules", l); });
    }
    function editRule(r) {
        startSteps([{ label: I18n.tr("Comando per %1", r.label), initial: r.text }], function (a) { var l = list("rules"); l[r.idx] = { criteria: l[r.idx].criteria, command: a[0] }; setList("rules", l); });
    }
    function removeAt(name, idx) { var l = list(name); l.splice(idx, 1); setList(name, l); }
    function removeBind(combo) { setList("keybindings", list("keybindings").filter(function (b) { return b.combo !== combo; })); }

    // minuti con "mai" per lo zero
    function minutesRow(path, label, fallback) {
        var r = number("shell", path, label, 0, 240, 1, 0, fallback);
        var v = Settings.get("shell", path);
        r.text = v === 0 ? I18n.tr("mai") : (typeof v === "number" ? I18n.tr("%1 min", v) : I18n.tr("predefinito"));
        return r;
    }

    function appsRows() {
        var out = [header(I18n.tr("Applicazioni predefinite"))];
        DefaultApps.groups.forEach(function (g) {
            var cands = DefaultApps.candidates[g.id] || [];
            var cur = DefaultApps.current[g.id] || "";
            if (cands.length === 0) { out.push(info(g.label, I18n.tr("nessuna applicazione trovata"))); return; }
            var found = cands.some(function (c) { return c.id === cur; });
            var row = choiceC("app:" + g.id, g.label, cands.map(function (c) { return { v: c.id, t: c.name }; }), found ? cur : "",
                              function (v) { DefaultApps.set(g.id, v); });
            if (!found) row.text = cur !== "" ? DefaultApps.nameOf(cur) : I18n.tr("non impostata");
            out.push(row);
        });
        out.push(info(I18n.tr("Nota"), I18n.tr("scrive ~/.config/mimeapps.list (xdg-mime e xdg-settings)")));
        return out;
    }

    function idleRows() {
        var out = [header(I18n.tr("Inattività"))];
        out.push(info(I18n.tr("Stato"), Idle.enabled ? I18n.tr("gestita da Vela") : I18n.tr("spenta (la gestisce altro, se presente)"), Idle.enabled ? "accent" : ""));
        out.push(choice("shell", "idle.enabled", I18n.tr("Gestione dell'inattività di Vela"), [{ v: true, t: "attiva" }, { v: false, t: "spenta" }]));
        if (Idle.enabled && Idle.externalRunning)
            out.push(info(I18n.tr("Attenzione"), I18n.tr("swayidle è in esecuzione: rischio di doppioni, va fermato"), "warn"));
        out.push(header(I18n.tr("A batteria")));
        out.push(minutesRow("idle.lockMinutes", I18n.tr("Blocca lo schermo dopo"), 5));
        out.push(minutesRow("idle.screenOffMinutes", I18n.tr("Spegni lo schermo dopo"), 10));
        out.push(minutesRow("idle.suspendMinutes", I18n.tr("Sospendi dopo"), 30));
        out.push(header(I18n.tr("Con l'alimentatore")));
        out.push(minutesRow("idle.lockMinutesOnAc", I18n.tr("Blocca lo schermo dopo"), 5));
        out.push(minutesRow("idle.screenOffMinutesOnAc", I18n.tr("Spegni lo schermo dopo"), 10));
        out.push(minutesRow("idle.suspendMinutesOnAc", I18n.tr("Sospendi dopo"), 0));
        out.push(header(I18n.tr("Blocco")));
        var fr = number("shell", "idle.fadeSeconds", I18n.tr("Dissolvenza prima del blocco"), 0, 30, 1, 0, 3);
        var fv = Settings.get("shell", "idle.fadeSeconds");
        fr.text = fv === 0 ? I18n.tr("nessuna") : (typeof fv === "number" ? I18n.tr("%1 s", fv) : I18n.tr("predefinito"));
        out.push(fr);
        var lc = Idle.lockCommand.join(" ");
        out.push({ kind: "text", file: "shell", path: "idle.lockCommand", label: I18n.tr("Comando di blocco"), value: lc, text: lc,
                   over: Settings.overridden("shell", "idle.lockCommand"), key: "shell:idle.lockCommand" });
        out.push({ kind: "action", label: I18n.tr("Blocca ora"), act: "lockNow", key: "a:locknow" });
        out.push({ kind: "action", label: I18n.tr("Ripristina questa scheda"), act: "resetTab", key: "a:resetTab" });
        return out;
    }

    function batteryRows() {
        var L = BatteryLimit;
        var out = [header(I18n.tr("Limite di carica"))];
        out.push(info(I18n.tr("Tipo"), L.mode === "fixed" ? I18n.tr("limite fisso del firmware") : I18n.tr("soglie regolabili (%1–%2%)", L.limitStart, L.limitEnd)));
        out.push(info(I18n.tr("Stato"), L.full ? I18n.tr("carica piena in corso") : L.limited ? I18n.tr("limite attivo") : I18n.tr("limite spento"), L.limited ? "accent" : ""));
        if (!L.helperInstalled) out.push(info(I18n.tr("Attenzione"), I18n.tr("manca l'helper di sistema: doas make install-system"), "warn"));
        if (L.error !== "") out.push(info(I18n.tr("Errore"), L.error, "warn"));
        out.push({ kind: "action", label: L.wanted ? I18n.tr("Spegni il limite di carica") : I18n.tr("Attiva il limite di carica"), act: "batteryLimit", key: "a:batlimit" });
        if (L.full || L.wanted)
            out.push({ kind: "action", label: L.full ? I18n.tr("Annulla la carica piena") : I18n.tr("Carica al 100% una volta"), act: "batteryFull", key: "a:batfull" });
        return out;
    }

    readonly property string homeUrl: "https://github.com/akamizi/vela"
    FileView {
        id: versionFile
        path: Quickshell.shellDir + "/../VERSION"
        blockLoading: true
        printErrors: false
    }
    readonly property string version: { try { return versionFile.text().trim() || I18n.tr("sconosciuta"); } catch (e) { return I18n.tr("sconosciuta"); } }

    function aboutRows() {
        var out = [{ kind: "logo", key: "logo" }];
        out.push(header(I18n.tr("Informazioni")));
        out.push(info(I18n.tr("Versione"), version));
        out.push(info(I18n.tr("Licenza"), "EUPL-1.2"));
        out.push(info(I18n.tr("Compositor"), Compositors.active ? Compositors.active.name : I18n.tr("non riconosciuto")));
        out.push(info(I18n.tr("Configurazione"), Config.userDir));
        out.push(header(I18n.tr("Progetto")));
        out.push(info(I18n.tr("Indirizzo"), homeUrl.replace("https://", "")));
        out.push({ kind: "action", label: I18n.tr("Apri la pagina del progetto"), act: "openHome", key: "a:home" });
        out.push({ kind: "action", label: I18n.tr("Apri le note di rilascio"), act: "openReleases", key: "a:releases" });
        return out;
    }

    function info(label, text, tone) { return { kind: "info", label: label, text: text, tone: tone || "", key: "i:" + label }; }

    function compositorRows() {
        var out = [header(I18n.tr("Compositor rilevati"))];
        Compositors.compositors.forEach(function (c) {
            var st = [];
            st.push(c.installed ? I18n.tr("installato") : I18n.tr("non installato"));
            if (c.running) st.push(I18n.tr("in esecuzione"));
            if (c.active) st.push(I18n.tr("sessione attuale"));
            out.push(info(c.name, st.join(" · "), c.active ? "accent" : ""));
        });
        var a = Compositors.active;
        if (a === null) {
            out.push(info(I18n.tr("Sessione"), I18n.tr("compositor non riconosciuto"), "warn"));
            return out;
        }
        out.push(header(I18n.tr("Backend di Vela per %1", a.name)));
        out.push(info(I18n.tr("Stato"), a.backend ? I18n.tr("disponibile") : I18n.tr("non ancora disponibile: barra e impostazioni limitate"), a.backend ? "" : "warn"));
        out.push(info(I18n.tr("File di configurazione"), a.config));
        if (Compositors.categories.length > 0) out.push(header(I18n.tr("Categorie di impostazioni")));
        Compositors.categories.forEach(function (c) { out.push(info(c.label, c.available ? I18n.tr("disponibile") : I18n.tr("in arrivo"), c.available ? "accent" : "")); });
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
        case "radio": return radioRows();
        case "rules": return rulesRows();
        case "gaps": return gapsRows();
        case "about": return aboutRows();
        case "battery": return batteryRows();
        case "idle": return idleRows();
        case "apps": return appsRows();
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
        if (tabId === "idle") Idle.checkExternal();
        if (tabId === "battery") BatteryLimit.refresh();
        if (tabId === "apps") DefaultApps.refresh();
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
        case "idle": return [["shell", "idle"]];
        case "bar": return [["shell", "bar.position"], ["shell", "bar.modules"], ["theme", "layout.barHeight"], ["theme", "layout.barRadius"], ["theme", "font.barSize"], ["theme", "barOpacity"]];
        case "weather": return [["shell", "weather.latitude"], ["shell", "weather.longitude"], ["shell", "weather.placeName"], ["shell", "weather.units"]];
        case "outputs": return [["sway", "outputs"]];
        case "input": return [["sway", "input"]];
        case "wallpaper": return [["sway", "wallpaper"]];
        case "radio": return [["shell", "radio.stations"]];
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
        if (r.kind === "station") { editStation(r); return; }
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
        else if (r.act === "lockNow") Idle.lock();
        else if (r.act === "batteryLimit") BatteryLimit.toggleLimit();
        else if (r.act === "batteryFull") BatteryLimit.toggleFull();
        else if (r.act === "openHome") Quickshell.execDetached(["xdg-open", homeUrl]);
        else if (r.act === "openReleases") Quickshell.execDetached(["xdg-open", homeUrl + "/releases"]);
        else if (r.act === "pickWallpaper") { picking = true; wallpaperPicker.begin(); }
        else if (r.act === "addBind") addBind();
        else if (r.act === "addAuto") addAuto();
        else if (r.act === "addStation") addStation();
        else if (r.act === "addRule") addRule();
        else if (r.act === "keepOutputs") SwayBackend.confirm();
        else if (r.act === "revertOutputs") SwayBackend.revert();
        else if (r.act === "addInclude")
            pendingConfirm = { text: I18n.tr("Aggiungere la riga include a %1 (copia: config.bak-vela-include)? Invio = sì, Esc = no", SwayBackend.swayConfigPath),
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
            if (!/^#[0-9a-fA-F]{6}$/.test(t)) { note = I18n.tr("Colore non valido: usare #rrggbb"); return; }
            t = t.toLowerCase();
        } else if (r.file === "sway") {
            if (t === "") { Settings.reset(r.file, r.path); cancelEdit(); return; }       // vuoto = predefinito
            if (r.path === "wallpaper.path") t = t.replace(/^~\//, Quickshell.env("HOME") + "/");
            if (!SwayBackend.safe(t)) { note = I18n.tr("Caratteri non ammessi (niente virgolette, $ o ;)"); return; }
        } else if (t === "") { note = I18n.tr("Valore vuoto"); return; }
        if (r.kind === "search") { Geocoding.search(t); cancelEdit(); return; }
        if (r.path === "idle.lockCommand") {                 // array di argomenti, separati da spazi
            Settings.set("shell", "idle.lockCommand", t.split(/\s+/).filter(function (x) { return x !== ""; }));
            cancelEdit();
            return;
        }
        Settings.set(r.file, r.path, t);
        cancelEdit();
    }
    function cancelEdit() { editing = null; note = ""; keys.forceActiveFocus(); }

    function resetRow(r) {
        if (r && r.kind === "bind") { removeBind(r.combo); return; }
        if (r && r.kind === "auto") { removeAt("autostart", r.idx); return; }
        if (r && r.kind === "station") { var sl = stations(); sl.splice(r.idx, 1); setStations(sl); return; }
        if (r && r.kind === "rule") { removeAt("rules", r.idx); return; }
        if (r && r.kind === "search") Settings.resetMany([["shell", "weather.latitude"], ["shell", "weather.longitude"], ["shell", "weather.placeName"]]);
        else if (r && r.file && r.over) Settings.reset(r.file, r.path);
        else if (r && r.kind === "module") Settings.resetMany([["shell", "bar.modules"]]);
    }

    onOpenChanged: {
        if (open) {
            editing = null; picking = false; confirmReset = false; pendingConfirm = null; note = "";
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
    contentHeight: picking ? cardHeight - 40 : headerHeight + 1 + (editing ? Theme.rowHeight * 2 + Theme.padding : listHeight + Theme.padding) + footerHeight

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
                else if (r && r.kind === "station") panel.moveStation(r, -1);
            } else if (shift && event.key === Qt.Key_Down) {
                if (r && r.kind === "module") panel.reorder(r, 1);
                else if (r && r.kind === "station") panel.moveStation(r, 1);
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
                text: I18n.tr("Impostazioni")
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
                        BarText { id: applyLabel; anchors.centerIn: parent; text: I18n.tr("Applica"); color: Theme.background }
                        TapHandler { onTapped: panel.submitEdit() }
                    }
                    Rectangle {
                        width: cancelLabel.implicitWidth + Theme.padding * 2; height: Theme.rowHeight - 6
                        radius: Theme.radius
                        color: Theme.border
                        BarText { id: cancelLabel; anchors.centerIn: parent; text: I18n.tr("Annulla") }
                        TapHandler { onTapped: panel.cancelEdit() }
                    }
                }
            }
        }

        WallpaperPicker {
            id: wallpaperPicker
            anchors { fill: parent; leftMargin: panel.sidebarWidth }
            visible: panel.picking
            z: 10
            onClosed: { panel.picking = false; keys.forceActiveFocus(); }
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
                    BarText { text: I18n.tr("Vela"); font.bold: true; font.pixelSize: Theme.fontSize + 8; anchors.horizontalCenter: parent.horizontalCenter }
                    BarText { text: I18n.tr("Shell desktop per Sway su Void Linux"); color: Theme.muted; anchors.horizontalCenter: parent.horizontalCenter }
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
                    title: entry.isHeader ? "" : ((entry.r.kind === "module" ? entry.r.name : entry.r.label) || "")
                    titleColor: entry.r.kind === "action" ? Theme.accent : Theme.foreground
                    trailingText: entry.isHeader || entry.r.kind === "action" || entry.r.kind === "logo" ? ""
                        : (entry.r.kind === "number" || entry.r.kind === "choice" ? "‹ " + entry.r.text + " ›" : (entry.r.text || ""))
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
                    if (panel.confirmReset) return I18n.tr("Ripristinare questa scheda? Invio = sì, Esc = no");
                    if (panel.pendingConfirm) return panel.pendingConfirm.text;
                    if (panel.editing) return I18n.tr("Invio = applica · Esc = annulla");
                    var r = panel.current();
                    if (panel.tabId === "compositor" && !(panel.current() && panel.current().kind === "action")) return I18n.tr("Informazioni sul compositor · Tab categoria · Esc chiudi");
                    if (r && r.kind === "bind") return r.own ? I18n.tr("Invio = cambia il comando · Canc rimuove · Tab categoria") : I18n.tr("Invio = cambia il comando · Canc toglie la sostituzione · Tab categoria");
                    if (r && (r.kind === "auto" || r.kind === "rule")) return I18n.tr("Invio = modifica · Canc rimuove · Tab categoria");
                    if (r && r.kind === "station") return I18n.tr("Invio = modifica · Canc rimuove · Maiusc+↑/↓ ordine · Tab categoria");
                    if (r && r.kind === "search") return I18n.tr("Invio = cerca una città · Canc ripristina · Tab categoria");
                    if (r && r.kind === "place") return I18n.tr("Invio = scegli questa città · Tab categoria");
                    if (r && r.kind === "module") return I18n.tr("←/→ zona · Maiusc+↑/↓ ordine · Canc ripristina · Tab scheda");
                    if (r && (r.kind === "number" || r.kind === "choice")) return I18n.tr("←/→ cambia · Canc ripristina · Tab scheda · Esc chiudi");
                    if (r && (r.kind === "color" || r.kind === "text")) return I18n.tr("Invio = modifica · Canc ripristina · Tab scheda");
                    return I18n.tr("Invio = applica · Tab scheda · Esc chiudi");
                }
            }
        }
        }
    }
}
