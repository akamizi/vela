// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello delle scorciatoie (D-023): al centro dello schermo, stesso stile degli altri. L'elenco si compone da solo
// dal config di Sway e dalle scorciatoie di Vela (core/shortcuts.js), quindi segue le impostazioni attuali.
// Digitando si filtra · ↑/↓ scorrono · Esc cancella il filtro, poi chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/shortcuts.js" as Shortcuts
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "shortcuts"
    cardWidth: 680
    cardHeight: 640
    centered: true

    readonly property int footerHeight: 28
    readonly property int searchHeight: 36

    property string query: ""
    property string currentKey: ""

    // --- elenco -------------------------------------------------------------------
    function programName(prog) {
        var e = DesktopEntries.heuristicLookup(prog);
        return e ? e.name : "";
    }
    readonly property var allRows: {
        if (!SwayBackend.active) return [{ kind: "message", text: "Nessun backend per questo compositor", key: "m:none" }];
        var loaded = DesktopEntries.applications.values.length;   // rilegge i nomi quando l'elenco delle app è pronto
        var rows = Shortcuts.build(SwayBackend.userConfig, Config.sway.keybindings, panel.programName);
        if (rows.length === 0) rows = [{ kind: "message", text: "Nessuna scorciatoia trovata nel config di Sway", key: "m:empty" }];
        return rows;
    }
    readonly property var rows: filter(allRows, query)
    readonly property int bindCount: allRows.filter(function (r) { return r.kind === "bind"; }).length

    function filter(list, q) {
        q = q.trim().toLowerCase();
        if (q === "") return list;
        var out = [], pending = null;
        list.forEach(function (r) {
            if (r.kind === "header") { pending = r; return; }
            if (r.kind !== "bind") return;
            var hay = (r.label + " " + r.keys.join(" ") + " " + r.tail).toLowerCase();
            if (hay.indexOf(q) < 0) return;
            if (pending) { out.push(pending); pending = null; }
            out.push(r);
        });
        if (out.length === 0) out.push({ kind: "message", text: "Nessuna scorciatoia corrisponde", key: "m:nomatch" });
        return out;
    }

    function selectable(r) { return r && r.kind === "bind"; }
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
            if (selectable(rows[i])) {
                select(i);
                // Il titolo della sezione resta visibile quando il cursore va sulla prima voce.
                if (i > 0 && rows[i - 1].kind === "header") list.positionViewAtIndex(i - 1, ListView.Contain);
                return;
            }
        }
    }
    function restoreSelection() {
        var idx = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].key === currentKey) { idx = i; break; }
        if (idx < 0) for (var j = 0; j < rows.length; j++) if (selectable(rows[j])) { idx = j; break; }
        list.currentIndex = idx;
        if (idx >= 0) { currentKey = rows[idx].key; list.positionViewAtIndex(idx, ListView.Contain); }
    }
    onRowsChanged: Qt.callLater(restoreSelection)

    onOpenChanged: {
        if (open) {
            query = "";
            currentKey = "";
            Qt.callLater(function () { restoreSelection(); list.positionViewAtBeginning(); });
            keys.forceActiveFocus();
        }
    }

    contentHeight: cardHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) {
                if (panel.query !== "") panel.query = ""; else Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_PageDown) {
                for (var a = 0; a < 8; a++) panel.move(1);
            } else if (event.key === Qt.Key_PageUp) {
                for (var b = 0; b < 8; b++) panel.move(-1);
            } else if (event.key === Qt.Key_Backspace) {
                panel.query = panel.query.slice(0, -1);
            } else if (!ctrl && event.text.length === 1 && event.text >= " ") {
                panel.query += event.text;
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: Icons.keyboard
            iconColor: Theme.accent
            title: "Scorciatoie"
            meta: Compositors.active ? Compositors.active.name : "compositor"
            detail: panel.bindCount > 0 ? panel.bindCount + " combinazioni" : ""
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        // Campo di ricerca: mostra quanto digitato (la tastiera la gestisce il FocusScope).
        Item {
            id: search
            anchors { top: sep.bottom; left: parent.left; right: parent.right }
            height: panel.searchHeight
            BarText {
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                color: panel.query === "" ? Theme.dim : Theme.foreground
                text: panel.query === "" ? "Digita per cercare…" : panel.query
            }
            PanelSeparator { anchors.bottom: parent.bottom }
        }

        ListView {
            id: list
            anchors { top: search.bottom; bottom: foot.top; left: parent.left; right: parent.right }
            topMargin: Theme.spacing / 2
            bottomMargin: Theme.spacing / 2
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
                readonly property bool isBind: r.kind === "bind"
                width: ListView.view.width
                height: r.kind === "header" ? 28 : Theme.rowHeight

                PanelSectionHeader { visible: entry.r.kind === "header"; text: entry.r.kind === "header" ? entry.r.label : "" }

                BarText {
                    visible: entry.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: entry.r.kind === "message" ? entry.r.text : ""
                    color: Theme.dim
                }

                PanelRow {
                    visible: entry.isBind
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    title: entry.isBind ? entry.r.label : ""
                    trailing: Component {
                        Row {
                            spacing: 4
                            Repeater {
                                model: entry.isBind ? entry.r.keys.concat(entry.r.tail !== "" ? [entry.r.tail] : []) : []
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool isSep: modelData === "|sep|"
                                    implicitWidth: Math.max(cap.implicitWidth + Theme.spacing * 1.5, cap.implicitHeight + 6)
                                    implicitHeight: cap.implicitHeight + 6
                                    radius: Theme.radius > 0 ? Math.min(Theme.radius, 6) : 0
                                    color: "transparent"
                                    border.width: isSep ? 0 : 1
                                    border.color: Theme.softBorder
                                    BarText {
                                        id: cap
                                        anchors.centerIn: parent
                                        text: isSep ? "/" : modelData
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontSize - 2
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                    onMoved: panel.select(entry.index)
                    onClicked: panel.select(entry.index)
                }
            }
        }

        Item {
            id: foot
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: panel.footerHeight
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
            BarText {
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize - 2
                color: Theme.dim
                text: "Digita per filtrare · ↑/↓ scorri · Esc " + (panel.query !== "" ? "cancella il filtro" : "chiude")
            }
        }
    }
}
