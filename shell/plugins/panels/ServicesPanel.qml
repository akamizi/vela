// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello dei servizi runit (D-047). Lo stato si legge senza privilegi; le azioni si aprono in un terminale con doas/sudo, che chiede la
// password: Vela non la vede mai. ↑/↓ = scorri · Spazio = avvia/ferma (abilita, se non lo è) · R = riavvia · E = abilita/disabilita · Esc chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "services"
    cardWidth: Math.max(Theme.panelWidth, 460)

    readonly property int footerHeight: 28
    readonly property int maxListHeight: 12 * Theme.rowHeight
    property string currentKey: ""

    readonly property var rows: Services.items.map(function (e) { return { kind: "service", e: e, key: e.id }; })
    readonly property int runningCount: Services.items.filter(function (e) { return e.running; }).length

    function stateText(e) { return !e.enabled ? I18n.tr("non abilitato") : e.running ? I18n.tr("attivo") : I18n.tr("fermo"); }

    function current() { return list.currentIndex >= 0 && list.currentIndex < rows.length ? rows[list.currentIndex] : null; }
    function select(i) {
        list.currentIndex = i;
        if (i >= 0 && i < rows.length) { currentKey = rows[i].key; list.positionViewAtIndex(i, ListView.Contain); }
    }
    function move(delta) {
        var n = rows.length;
        if (n > 0) select((Math.max(0, list.currentIndex) + delta + n) % n);
    }
    function restoreSelection() {
        var idx = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].key === currentKey) { idx = i; break; }
        if (idx < 0 && rows.length > 0) idx = 0;
        list.currentIndex = idx;
    }
    onRowsChanged: Qt.callLater(restoreSelection)

    // Un servizio non abilitato non ha il collegamento in /var/service: `sv start` non può funzionare, si abilita (runit lo avvia da solo in pochi secondi).
    function toggleRun(r) { if (r) Services.act(!r.e.enabled ? "enable" : r.e.running ? "stop" : "start", r.e.id); }
    function restart(r) { if (r && r.e.enabled && r.e.running) Services.act("restart", r.e.id); }
    function toggleEnabled(r) { if (r) Services.act(r.e.enabled ? "disable" : "enable", r.e.id); }

    onOpenChanged: {
        if (open) { Services.refresh(); currentKey = ""; keys.forceActiveFocus(); }
    }
    Timer { interval: 3000; running: panel.open; repeat: true; onTriggered: Services.refresh() }

    property real listHeight: Math.min(Math.max(1, rows.length) * Theme.rowHeight + Theme.spacing, maxListHeight)
    contentHeight: hero.implicitHeight + 1 + listHeight + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            var r = panel.current();
            if (event.key === Qt.Key_Escape) Runtime.closePanel();
            else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) panel.move(1);
            else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) panel.move(-1);
            else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.toggleRun(r);
            else if (event.key === Qt.Key_R) panel.restart(r);
            else if (event.key === Qt.Key_E) panel.toggleEnabled(r);
            else return;
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: Icons.server
            iconColor: Services.available ? Theme.accent : Theme.muted
            title: I18n.tr("Servizi")
            meta: !Services.available ? "" : I18n.tr("%1 di %2 attivi", String(panel.runningCount), String(Services.items.length))
            detail: Services.busy ? I18n.tr("in corso nel terminale") : ""
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

            delegate: PanelRow {
                id: entry
                required property var modelData
                required property int index
                width: ListView.view.width - 2 * Theme.spacing
                x: Theme.spacing
                height: Theme.rowHeight
                hasCursor: ListView.isCurrentItem
                icon: Icons.server
                iconColor: modelData.e.enabled && modelData.e.running ? Theme.accent : Theme.muted
                title: modelData.e.label
                trailingText: panel.stateText(modelData.e)
                trailingColor: modelData.e.enabled && modelData.e.running ? Theme.accent : Theme.muted
                onMoved: panel.select(entry.index)
                onClicked: { panel.select(entry.index); panel.toggleRun(modelData); }
            }

            BarText {
                visible: panel.rows.length === 0
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; top: parent.top; topMargin: Theme.spacing }
                text: Services.available ? I18n.tr("Nessun servizio configurato è installato") : I18n.tr("Lettura in corso…")
                color: Theme.dim
                elide: Text.ElideRight
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
                text: I18n.tr("Spazio avvia/ferma (o abilita) · R riavvia · E abilita/disabilita (chiede la password) · Esc chiude")
            }
        }
    }
}
