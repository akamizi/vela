// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello Impostazioni, gradino 1: aspetto (schede Barra e Tema). Scrive solo settings.jsonc (D-021),
// con anteprima immediata. Su: ↑/↓ · ←/→ cambia valore · Invio modifica · Canc ripristina · Tab cambia scheda.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
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

    property int tab: 0                       // 0 = Barra, 1 = Tema, 2 = Compositor
    readonly property var tabNames: ["Barra", "Tema", "Compositor"]
    property var editing: null                // riga in modifica (colore o testo)
    property bool confirmReset: false
    property string currentKey: ""
    property string note: ""

    // --- righe ------------------------------------------------------------------------
    function fmt(v, dec) { return dec > 0 ? v.toFixed(dec) : String(Math.round(v)); }

    function number(file, path, label, min, max, step, dec) {
        var v = Settings.get(file, path);
        return { kind: "number", file: file, path: path, label: label, min: min, max: max, step: step, dec: dec,
                 value: v, text: fmt(v, dec), over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function choice(file, path, label, options) {
        var v = Settings.get(file, path), t = String(v);
        options.forEach(function (o) { if (o.v === v) t = o.t; });
        return { kind: "choice", file: file, path: path, label: label, options: options, value: v, text: t,
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function color(file, path, label) {
        var v = Settings.get(file, path);
        return { kind: "color", file: file, path: path, label: label, value: v, text: v,
                 over: Settings.overridden(file, path), key: file + ":" + path };
    }
    function textRow(file, path, label) {
        var v = Settings.get(file, path);
        return { kind: "text", file: file, path: path, label: label, value: v, text: v,
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
        return out;
    }

    readonly property var rows: tab === 0 ? barRows() : tab === 1 ? themeRows() : compositorRows()
    function selectable(r) { return r && r.kind !== "header" && r.kind !== "info"; }
    function current() { return rows[list.currentIndex] || null; }

    // La selezione è ricordata per chiave, non per indice: l'elenco si ricostruisce a ogni modifica.
    function select(i) {
        list.currentIndex = i;
        if (i >= 0 && i < rows.length) currentKey = rows[i].key;
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
    }
    onRowsChanged: Qt.callLater(restoreSelection)

    onTabChanged: { currentKey = ""; confirmReset = false; if (tab === 2) Compositors.refresh(); }

    // --- azioni -----------------------------------------------------------------------
    function round(v, dec) { var m = Math.pow(10, dec); return Math.round(v * m) / m; }

    function step(r, dir) {
        if (r.kind === "number") {
            var v = Math.max(r.min, Math.min(r.max, round(r.value + dir * r.step, r.dec + 2)));
            Settings.set(r.file, r.path, v);
        } else if (r.kind === "choice") {
            var idx = 0;
            r.options.forEach(function (o, i) { if (o.v === r.value) idx = i; });
            Settings.set(r.file, r.path, r.options[(idx + dir + r.options.length) % r.options.length].v);
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
        return tab === 0
            ? [["shell", "bar.position"], ["shell", "bar.modules"], ["theme", "layout.barHeight"], ["theme", "layout.barRadius"], ["theme", "font.barSize"], ["theme", "barOpacity"]]
            : [["theme", "colors"], ["theme", "font.family"], ["theme", "font.size"], ["theme", "layout.radius"]];
    }

    function activate(r) {
        if (!r) return;
        if (r.kind === "color" || r.kind === "text") { startEdit(r); return; }
        if (r.kind === "number" || r.kind === "choice") { step(r, 1); return; }
        if (r.kind !== "action") return;
        if (r.act === "presetDark") Settings.resetMany([["theme", "colors"]]);
        else if (r.act === "presetLight") Settings.setMany("theme", light);
        else if (r.act === "resetModules") Settings.resetMany([["shell", "bar.modules"]]);
        else if (r.act === "resetTab") confirmReset = true;
    }

    function startEdit(r) {
        editing = r;
        note = "";
        editor.begin(String(r.value));
        field.forceActiveFocus();
        field.selectAll();
    }
    function submitEdit() {
        var r = editing, t = field.text.trim();
        if (r.kind === "color") {
            if (/^[0-9a-fA-F]{6}$/.test(t)) t = "#" + t;
            if (!/^#[0-9a-fA-F]{6}$/.test(t)) { note = "Colore non valido: usare #rrggbb"; return; }
            t = t.toLowerCase();
        } else if (t === "") { note = "Valore vuoto"; return; }
        Settings.set(r.file, r.path, t);
        cancelEdit();
    }
    function cancelEdit() { editing = null; note = ""; keys.forceActiveFocus(); }

    function resetRow(r) {
        if (r && r.file && r.over) Settings.reset(r.file, r.path);
        else if (r && r.kind === "module") Settings.resetMany([["shell", "bar.modules"]]);
    }

    onOpenChanged: {
        if (open) {
            editing = null; confirmReset = false; note = "";
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
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: parent.width
                        height: Theme.rowHeight
                        color: index === panel.tab ? Theme.border : "transparent"
                        Rectangle { visible: index === panel.tab; width: 3; height: parent.height; color: Theme.accent }
                        BarText {
                            anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                            text: modelData
                            font.bold: index === panel.tab
                            color: index === panel.tab ? Theme.foreground : Theme.muted
                        }
                        MouseArea { anchors.fill: parent; onClicked: panel.tab = parent.index }
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
                text: panel.editing ? panel.editing.label : ""
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

            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property var r: modelData
                readonly property bool isHeader: r.kind === "header"
                width: ListView.view.width
                height: isHeader ? panel.sectionHeight : Theme.rowHeight
                color: ListView.isCurrentItem && panel.selectable(r) ? Theme.border : "transparent"

                BarText {
                    visible: item.isHeader
                    anchors { left: parent.left; leftMargin: Theme.padding; bottom: parent.bottom; bottomMargin: 2 }
                    text: item.isHeader ? item.r.label.toUpperCase() : ""
                    color: Theme.dim
                    font.pixelSize: Theme.fontSize - 2
                    font.letterSpacing: 1
                }

                // impostazione (numero, scelta, colore, testo, elemento)
                Item {
                    visible: !item.isHeader
                    anchors.fill: parent

                    // punto: il valore è stato impostato dal pannello
                    Rectangle {
                        visible: !item.isHeader && item.r.over === true
                        width: 5; height: 5; radius: 3
                        color: Theme.accent
                        anchors { left: parent.left; leftMargin: Theme.padding / 2 - 2; verticalCenter: parent.verticalCenter }
                    }
                    BarText {
                        anchors { left: parent.left; leftMargin: Theme.padding; right: valueRow.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        text: item.isHeader ? "" : (item.r.kind === "module" ? item.r.name : item.r.label)
                        elide: Text.ElideRight
                        color: item.r.kind === "action" ? Theme.accent : Theme.foreground
                    }
                    Row {
                        id: valueRow
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        spacing: Theme.spacing
                        Rectangle {
                            visible: !item.isHeader && item.r.kind === "color"
                            width: 14; height: 14
                            radius: 2
                            color: !item.isHeader && item.r.kind === "color" ? item.r.value : "transparent"
                            border.color: Theme.dim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        BarText {
                            width: !item.isHeader && item.r.kind === "color" ? 64 : implicitWidth
                            horizontalAlignment: Text.AlignRight
                            text: item.isHeader || item.r.kind === "action" ? "" : (item.r.kind === "number" || item.r.kind === "choice" ? "‹ " + item.r.text + " ›" : item.r.text)
                            color: item.isHeader ? Theme.muted
                                 : item.r.kind === "module" && item.r.zone === "hidden" ? Theme.dim
                                 : item.r.kind === "info" && item.r.tone === "accent" ? Theme.accent
                                 : item.r.kind === "info" && item.r.tone === "warn" ? Theme.warning
                                 : Theme.muted
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: panel.selectable(item.r)
                    hoverEnabled: true
                    // Seleziona solo se il mouse si muove davvero: quando l'anteprima sposta la scheda
                    // sotto un puntatore fermo arriva un movimento sintetico che non va seguito.
                    property point last: Qt.point(-1, -1)
                    onPositionChanged: mouse => {
                        var g = mapToGlobal(mouse.x, mouse.y);
                        if (g.x === last.x && g.y === last.y) return;
                        last = g;
                        panel.select(item.index);
                    }
                    onClicked: { panel.select(item.index); panel.activate(item.r); }
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
                color: panel.confirmReset || panel.note !== "" ? Theme.warning : Theme.dim
                text: {
                    if (panel.note !== "") return panel.note;
                    if (panel.confirmReset) return "Ripristinare questa scheda? Invio = sì, Esc = no";
                    if (panel.editing) return "Invio = applica · Esc = annulla";
                    var r = panel.current();
                    if (panel.tab === 2) return "Informazioni sul compositor · Tab categoria · Esc chiudi";
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
