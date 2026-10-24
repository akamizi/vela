// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello degli schermi (D-044): luminosità e luce notturna, modalità rapide (solo interno, solo esterno, estendi) e,
// per ogni schermo, risoluzione e scala. Ogni modifica passa da SwayBackend con la conferma di 15 secondi (poi si torna indietro da soli).
// ↑/↓ = scorri · Invio = applica / mantieni · ←/→ = cambia il valore (luminosità ±passo) · Spazio = luce notturna ·
// Esc = ripristina (se in attesa) o chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "display"
    cardWidth: Math.max(Theme.panelWidth, 460)

    readonly property int footerHeight: 28
    readonly property int maxListHeight: 14 * Theme.rowHeight
    readonly property int mapHeight: 128

    property string currentKey: ""

    // --- schermi -------------------------------------------------------------------
    readonly property var outs: SwayBackend.outputs
    readonly property int activeCount: outs.filter(function (o) { return o.active; }).length
    readonly property string currentMode: SwayBackend.displayMode

    // Mappa degli schermi accesi (solo con due o più): lo schermo scelto si sposta con Maiusc+frecce.
    readonly property var activeOuts: outs.filter(function (o) { return o.active; })
    property string mapSel: ""
    readonly property string mapSelected: {
        for (var i = 0; i < activeOuts.length; i++) if (activeOuts[i].name === mapSel) return mapSel;
        return activeOuts.length > 0 ? SwayBackend.internalName : "";
    }
    function mapStep(dir) {
        var n = activeOuts.length;
        if (n < 2) return;
        var names = activeOuts.map(function (o) { return o.name; }).sort();
        mapSel = names[(Math.max(0, names.indexOf(mapSelected)) + dir + n) % n];
    }
    function mapPlace(side) { if (mapSelected !== "") SwayBackend.placeOutput(mapSelected, side); }
    function applyMode(kind) { SwayBackend.applyDisplayMode(kind); }

    function uniq(list) {
        var seen = {}, out = [];
        list.forEach(function (v) { if (!seen[v]) { seen[v] = true; out.push(v); } });
        return out;
    }
    function cycleMode(name, dir) {
        var o = SwayBackend.find(name);
        if (!o || !o.active) return;
        var list = uniq(o.modes), i = list.indexOf(o.mode);
        if (list.length === 0) return;
        SwayBackend.setOutput(name, { mode: list[(i + dir + list.length) % list.length] });
    }
    function stepScale(name, dir) {
        var o = SwayBackend.find(name);
        if (!o || !o.active) return;
        var v = Math.max(0.5, Math.min(3, Math.round((o.scale + dir * 0.25) * 4) / 4));
        if (v !== o.scale) SwayBackend.setOutput(name, { scale: v });
    }

    // --- luminosità e luce notturna -------------------------------------------------
    readonly property bool hasNight: MenuModel.found["gammastep"] === true || Toggles.night
    // Uscita che ha la barra (bar.screen); vuoto = tutte.
    readonly property string barScreen: Config.shell.bar.screen || ""
    readonly property real brightnessStep: Config.shell.brightness.step / 100
    function nudgeBrightness(delta) { Brightness.set(Math.max(0.01, Math.min(1, Brightness.level + delta))); }

    // --- elenco -------------------------------------------------------------------
    function buildRows() {
        var out = [];
        if (Brightness.available || hasNight) {
            out.push({ kind: "header", label: I18n.tr("Luminosità e colore"), key: "h-light" });
            if (Brightness.available) out.push({ kind: "bright", label: I18n.tr("Luminosità"), key: "bright" });
            if (hasNight) out.push({ kind: "night", label: I18n.tr("Luce notturna"), key: "night" });
        }
        if (SwayBackend.pending) {
            out.push({ kind: "header", label: I18n.tr("Conferma"), key: "h-confirm" });
            out.push({ kind: "message", text: I18n.tr("Mantenere queste impostazioni? Tra %1 s si torna indietro", String(SwayBackend.countdown)),
                       warn: true, key: "m-confirm" });
            out.push({ kind: "action", act: "keep", label: I18n.tr("Mantieni"), icon: Icons.check, key: "a:keep" });
            out.push({ kind: "action", act: "revert", label: I18n.tr("Ripristina ora"), icon: Icons.power, key: "a:revert" });
        }
        if (outs.length >= 2) {
            out.push({ kind: "header", label: I18n.tr("Modalità"), key: "h-modes" });
            out.push({ kind: "mode", id: "internal", label: I18n.tr("Solo schermo interno"), icon: Icons.laptop, key: "mode:internal" });
            out.push({ kind: "mode", id: "external", label: I18n.tr("Solo schermi esterni"), icon: Icons.monitor, key: "mode:external" });
            out.push({ kind: "mode", id: "extend", label: I18n.tr("Estendi"), icon: Icons.monitorMultiple, key: "mode:extend" });
            if (SwayBackend.hasMirror)
                out.push({ kind: "mode", id: "mirror", label: I18n.tr("Duplica"), icon: Icons.duplicate, key: "mode:mirror" });
            else
                out.push({ kind: "message", text: I18n.tr("Duplica: serve il programma wl-mirror"), key: "m-mirror" });
        }
        if (activeOuts.length >= 2) {
            out.push({ kind: "header", label: I18n.tr("Disposizione"), key: "h-map" });
            out.push({ kind: "map", key: "map" });
        }
        outs.forEach(function (o) {
            out.push({ kind: "header", label: o.name + (o.label ? " — " + o.label : ""), key: "h:" + o.name });
            if (!o.active) { out.push({ kind: "message", text: I18n.tr("spento"), key: "m:" + o.name }); return; }
            out.push({ kind: "res", name: o.name, label: I18n.tr("Risoluzione e frequenza"), value: o.mode, key: "res:" + o.name });
            out.push({ kind: "scale", name: o.name, label: I18n.tr("Scala"), value: String(o.scale), key: "scale:" + o.name });
            if (activeOuts.length >= 2)
                out.push({ kind: "barhere", name: o.name, label: I18n.tr("Barra solo su questo schermo"), key: "barhere:" + o.name });
        });
        if (outs.length === 0) out.push({ kind: "message", text: I18n.tr("nessuno schermo rilevato"), key: "m-none" });
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && (r.kind === "mode" || r.kind === "res" || r.kind === "scale" || r.kind === "barhere" || r.kind === "action" || r.kind === "map" || r.kind === "bright" || r.kind === "night"); }
    function current() { var r = rows[list.currentIndex]; return selectable(r) ? r : null; }

    function select(i) {
        list.currentIndex = i;
        if (i >= 0 && i < rows.length) { currentKey = rows[i].key; list.positionViewAtIndex(i, ListView.Contain); }
    }
    function move(delta) {
        var n = rows.length;
        if (n === 0) return;
        var i = list.currentIndex;
        for (var step = 0; step < n; step++) {
            i = (i + delta + n) % n;
            if (selectable(rows[i])) { select(i); return; }
        }
    }
    function restoreSelection() {
        var idx = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].key === currentKey) { idx = i; break; }
        if (idx < 0) for (var j = 0; j < rows.length; j++) if (selectable(rows[j])) { idx = j; break; }
        list.currentIndex = idx;
        if (idx >= 0) list.positionViewAtIndex(idx, ListView.Contain);
    }
    onRowsChanged: Qt.callLater(restoreSelection)

    function activate(r) {
        if (!r) return;
        if (r.kind === "night") Toggles.toggleNight();
        else if (r.kind === "mode") applyMode(r.id);
        else if (r.kind === "barhere") Settings.set("shell", "bar.screen", barScreen === r.name ? "" : r.name);
        else if (r.kind === "action") { if (r.act === "keep") SwayBackend.confirm(); else SwayBackend.revert(); }
    }
    function change(r, dir) {
        if (!r) return;
        if (r.kind === "bright") nudgeBrightness(dir * brightnessStep);
        else if (r.kind === "map") mapStep(dir);
        else if (r.kind === "res") cycleMode(r.name, dir);
        else if (r.kind === "scale") stepScale(r.name, dir);
    }

    onOpenChanged: {
        if (open) {
            SwayBackend.refresh();
            Brightness.read();
            currentKey = "";
            for (var i = 0; i < rows.length; i++) if (selectable(rows[i])) { select(i); break; }
            keys.forceActiveFocus();
        }
    }

    // --- aspetto ------------------------------------------------------------------------
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 60); i++) h += rows[i].kind === "header" ? 28 : rows[i].kind === "map" ? mapHeight : Theme.rowHeight;
        return Math.min(h + Theme.spacing, maxListHeight);
    }
    contentHeight: hero.implicitHeight + 1 + listHeight + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            var r = panel.current();
            if (event.key === Qt.Key_Escape) {
                if (SwayBackend.pending) SwayBackend.revert(); else Runtime.closePanel();
            } else if (r && r.kind === "map" && (event.modifiers & Qt.ShiftModifier)
                       && (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                // Maiusc+freccia sulla mappa: lo schermo scelto passa a quel lato dell'altro
                panel.mapPlace(event.key === Qt.Key_Left ? "left" : event.key === Qt.Key_Right ? "right" : event.key === Qt.Key_Up ? "above" : "below");
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Space && r && r.kind === "night") {
                Toggles.toggleNight();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (SwayBackend.pending && !(r && r.kind === "action")) SwayBackend.confirm(); else panel.activate(r);
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                panel.change(r, 1);
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                panel.change(r, -1);
            } else {
                return;
            }
            event.accepted = true;
        }

        Component {
            id: brightTrail
            PanelSlider {
                implicitWidth: 140
                value: Brightness.level
                maxValue: 1
                onMoved: v => Brightness.set(Math.max(0.01, v))
            }
        }
        Component {
            id: nightTrail
            ToggleSwitch {
                checked: Toggles.night
                onToggled: Toggles.toggleNight()
            }
        }

        PanelHero {
            id: hero
            icon: panel.activeCount > 1 ? Icons.monitorMultiple : Icons.monitor
            iconColor: panel.activeCount > 0 ? Theme.accent : Theme.muted
            title: I18n.tr("Schermi")
            meta: panel.outs.length === 0 ? I18n.tr("nessuno rilevato")
                : panel.outs.length === 1 ? panel.outs[0].name
                : I18n.tr("%1 collegati, %2 accesi", String(panel.outs.length), String(panel.activeCount))
            detail: panel.outs.length > 0 && panel.outs[0].active ? panel.outs[0].mode.replace(/@.*/, "") : ""
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        ListView {
            id: list
            anchors { top: sep.bottom; left: parent.left; right: parent.right }
            height: panel.listHeight
            topMargin: Theme.spacing / 2
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
                width: ListView.view.width
                height: r.kind === "header" ? 28 : r.kind === "map" ? panel.mapHeight : Theme.rowHeight

                // Mappa: gli schermi accesi in scala, quello scelto col bordo colore accento.
                Item {
                    id: map
                    visible: entry.r.kind === "map"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    readonly property real pad: 14
                    readonly property real minX: Math.min.apply(null, panel.activeOuts.map(function (o) { return o.x; }).concat([0]))
                    readonly property real minY: Math.min.apply(null, panel.activeOuts.map(function (o) { return o.y; }).concat([0]))
                    readonly property real totW: Math.max(1, Math.max.apply(null, panel.activeOuts.map(function (o) { return o.x + o.w; }).concat([1])) - minX)
                    readonly property real totH: Math.max(1, Math.max.apply(null, panel.activeOuts.map(function (o) { return o.y + o.h; }).concat([1])) - minY)
                    readonly property real k: Math.min((width - 2 * pad) / totW, (height - 2 * pad) / totH)
                    readonly property real offX: (width - totW * k) / 2
                    readonly property real offY: (height - totH * k) / 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: "transparent"
                        border.width: entry.ListView.isCurrentItem ? 1 : 0
                        border.color: Theme.border
                    }
                    Repeater {
                        model: entry.r.kind === "map" ? panel.activeOuts : []
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool chosen: modelData.name === panel.mapSelected
                            x: map.offX + (modelData.x - map.minX) * map.k
                            y: map.offY + (modelData.y - map.minY) * map.k
                            width: Math.max(8, modelData.w * map.k) - 2
                            height: Math.max(8, modelData.h * map.k) - 2
                            radius: 3
                            color: chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Theme.surface
                            border.width: chosen ? 2 : 1
                            border.color: chosen ? Theme.accent : Theme.border
                            BarText {
                                anchors.centerIn: parent
                                width: parent.width - 6
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSize - 2
                                text: modelData.name + "\n" + modelData.w + "×" + modelData.h
                                color: chosen ? Theme.foreground : Theme.muted
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { panel.select(entry.index); panel.mapSel = modelData.name; }
                            }
                        }
                    }
                }

                PanelSectionHeader { visible: entry.r.kind === "header"; text: entry.r.kind === "header" ? entry.r.label : "" }

                BarText {
                    visible: entry.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: entry.r.kind === "message" ? entry.r.text : ""
                    color: entry.r.kind === "message" && entry.r.warn ? Theme.warning : Theme.dim
                    elide: Text.ElideRight
                }

                PanelRow {
                    visible: panel.selectable(entry.r) && entry.r.kind !== "map"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    selected: (entry.r.kind === "mode" && entry.r.id === panel.currentMode) || (entry.r.kind === "barhere" && entry.r.name === panel.barScreen)
                    icon: entry.r.kind === "mode" || entry.r.kind === "action" ? entry.r.icon
                        : entry.r.kind === "bright" ? Icons.pick(Icons.brightness, Brightness.level)
                        : entry.r.kind === "night" ? Icons.night : ""
                    trailing: entry.r.kind === "bright" ? brightTrail : entry.r.kind === "night" ? nightTrail : null
                    iconColor: (entry.r.kind === "mode" && entry.r.id === panel.currentMode) || entry.r.kind === "bright"
                               || (entry.r.kind === "night" && Toggles.night) ? Theme.accent : Theme.muted
                    title: panel.selectable(entry.r) ? (entry.r.label || "") : ""
                    bold: entry.r.kind === "mode" && entry.r.id === panel.currentMode
                    trailingText: entry.r.kind === "res" || entry.r.kind === "scale" ? "‹ " + entry.r.value + " ›"
                                : entry.r.kind === "bright" ? Math.round(Brightness.level * 100) + "%" : ""
                    onMoved: panel.select(entry.index)
                    onClicked: { panel.select(entry.index); panel.activate(entry.r); }
                }
            }
        }

        Item {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: panel.footerHeight
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
            BarText {
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize - 2
                color: Theme.dim
                text: SwayBackend.pending ? I18n.tr("Invio mantieni · Esc ripristina")
                    : panel.current() && panel.current().kind === "bright" ? I18n.tr("←/→ luminosità · Esc chiude")
                    : panel.current() && panel.current().kind === "night" ? I18n.tr("Invio o Spazio accende/spegne la luce notturna · Esc chiude")
                    : panel.current() && panel.current().kind === "map" ? I18n.tr("←/→ scegli lo schermo · Maiusc+frecce lo sposta · Esc chiude")
                    : I18n.tr("Invio applica · ←/→ cambia valore · Esc chiude")
            }
        }
    }
}
