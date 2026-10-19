// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello web radio (D-023, D-026): al centro, con le stazioni di radio.stations. Invio o clic = ascolta (ancora = ferma),
// digitando si filtra, ↑/↓ scorrono, Esc cancella il filtro e poi chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "radio"
    cardWidth: 520
    cardHeight: 560
    centered: true

    readonly property int footerHeight: 28
    readonly property int searchHeight: 36

    property string query: ""
    property string currentKey: ""

    // --- elenco -------------------------------------------------------------------
    readonly property var rows: {
        var q = query.trim().toLowerCase();
        var list = Radio.stations.filter(function (s) { return q === "" || s.name.toLowerCase().indexOf(q) >= 0; });
        if (Radio.stations.length === 0)
            return [{ kind: "message", text: "Nessuna stazione: aggiungile in radio.stations (~/.config/vela/shell.jsonc)", key: "m:none" }];
        if (list.length === 0) return [{ kind: "message", text: "Nessuna stazione corrisponde", key: "m:nomatch" }];
        var out = [];
        if (Radio.playing || Radio.state === "error") out.push({ kind: "stop", key: "stop" });
        out.push({ kind: "header", label: "Stazioni", key: "h:st" });
        list.forEach(function (s) { out.push({ kind: "station", s: s, key: "st:" + s.url }); });
        return out;
    }

    function selectable(r) { return r && (r.kind === "station" || r.kind === "stop"); }
    function current() { var r = rows[list.currentIndex]; return selectable(r) ? r : null; }
    function activate(r) {
        if (!r) return;
        if (r.kind === "stop") Radio.stop();
        else Radio.toggle(r.s);
    }

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
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                panel.activate(panel.current());
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
            icon: Icons.radio
            iconColor: Radio.state === "error" ? Theme.warning : Radio.playing ? Theme.accent : Theme.muted
            title: "Radio"
            meta: Radio.state === "stopped" ? "ferma" : Radio.name
            detail: Radio.state === "starting" ? "connessione…" : Radio.state === "playing" ? "in onda" : Radio.state === "error" ? Radio.error : ""
            trailing: Component {
                ToggleSwitch {
                    visible: Radio.playing
                    checked: Radio.playing
                    onToggled: Radio.stop()
                }
            }
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

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
                readonly property bool isStation: r.kind === "station"
                width: ListView.view.width
                height: r.kind === "header" ? 28 : Theme.rowHeight

                PanelSectionHeader { visible: entry.r.kind === "header"; text: entry.r.kind === "header" ? entry.r.label : "" }

                BarText {
                    visible: entry.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    wrapMode: Text.WordWrap
                    text: entry.r.kind === "message" ? entry.r.text : ""
                    color: Theme.dim
                }

                PanelRow {
                    visible: entry.r.kind === "stop" || entry.isStation
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    selected: entry.isStation && Radio.playing && Radio.url === entry.r.s.url
                    icon: entry.r.kind === "stop" ? Icons.pause : Icons.radio
                    iconColor: selected ? Theme.accent : Theme.muted
                    title: entry.r.kind === "stop" ? "Ferma" : entry.isStation ? entry.r.s.name : ""
                    bold: selected
                    onMoved: panel.select(entry.index)
                    onClicked: { panel.select(entry.index); panel.activate(entry.r); }
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
                text: "Invio ascolta / ferma · digita per filtrare · ↑/↓ scorri · Esc " + (panel.query !== "" ? "cancella il filtro" : "chiude")
            }
        }
    }
}
