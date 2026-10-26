// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Base dei pannelli a due livelli (Musica, Subsonic), nello stile del pannello Radio: elenco filtrabile al centro dello schermo.
// Il chiamante fornisce le righe già filtrate per `query` e reagisce a `activated` e `back`.
// Righe: {kind: "header", label} | {kind: "message", text} | {kind: "stop"} | {kind: "item", label, icon?, selected?}; ognuna con `key` unico.
// Tastiera: ↑/↓ scorrono, Invio attiva, digitando si filtra; Esc cancella il filtro, poi torna indietro (se canGoBack), poi chiude.
import QtQuick
import Quickshell
import "../core"
import "../core/icons.js" as Icons
import "../services"
import "."

PanelHost {
    id: panel
    cardWidth: 520
    cardHeight: 560
    centered: true

    property string icon: Icons.music
    property string title: ""
    property string meta: ""
    property string detail: ""
    property color iconColor: Theme.muted
    property var rows: []
    property bool canGoBack: false
    property string footerHint: ""
    property bool stopVisible: Player.playing
    property string query: ""

    signal activated(var row)
    signal back()
    signal opened()

    readonly property int footerHeight: 28
    readonly property int searchHeight: 36
    property string currentKey: ""

    function selectable(r) { return r && (r.kind === "item" || r.kind === "stop"); }
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
            opened();
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
                if (panel.query !== "") panel.query = "";
                else if (panel.canGoBack) panel.back();
                else Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_PageDown) {
                for (var a = 0; a < 8; a++) panel.move(1);
            } else if (event.key === Qt.Key_PageUp) {
                for (var b = 0; b < 8; b++) panel.move(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var r = panel.current();
                if (r) panel.activated(r);
            } else if (event.key === Qt.Key_Backspace) {
                if (panel.query !== "") panel.query = panel.query.slice(0, -1);
                else if (panel.canGoBack) panel.back();
            } else if (!ctrl && event.text.length === 1 && event.text >= " ") {
                panel.query += event.text;
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: panel.icon
            iconColor: panel.iconColor
            title: panel.title
            meta: panel.meta
            detail: panel.detail
            trailing: Component {
                ToggleSwitch {
                    visible: panel.stopVisible
                    checked: panel.stopVisible
                    onToggled: Player.stop()
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
                text: panel.query === "" ? I18n.tr("Digita per cercare…") : panel.query
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
                    visible: entry.r.kind === "stop" || entry.r.kind === "item"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    selected: entry.r.kind === "item" && entry.r.selected === true
                    icon: entry.r.kind === "stop" ? Icons.pause : (entry.r.icon || Icons.music)
                    iconColor: selected ? Theme.accent : Theme.muted
                    title: entry.r.kind === "stop" ? I18n.tr("Ferma") : (entry.r.kind === "item" ? entry.r.label : "")
                    bold: selected
                    onMoved: panel.select(entry.index)
                    onClicked: { panel.select(entry.index); panel.activated(entry.r); }
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
                text: panel.footerHint
            }
        }
    }
}
