// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello audio: uscite e ingressi con volume per dispositivo.
// Invio = rendi predefinito · ←/→ = volume · M = muto · Esc = chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "audio"

    readonly property int headerHeight: Theme.rowHeight
    readonly property int sectionHeight: 26
    readonly property int footerHeight: 28
    readonly property int maxRows: 12

    property string currentKey: ""
    readonly property real step: Config.shell.audio.step * 2.5   // passo del pannello: 5% col valore di default

    // --- elenco -------------------------------------------------------------------
    function buildRows() {
        var out = [];
        out.push({ kind: "header", label: "Uscite", key: "h-out" });
        AudioDevices.sinks.forEach(function (d) { out.push({ kind: "device", d: d, sink: true, key: "dev:" + d.id }); });
        if (AudioDevices.sinks.length === 0) out.push({ kind: "message", text: "Nessuna uscita audio", tone: "dim", key: "m-out" });
        out.push({ kind: "header", label: "Ingressi", key: "h-in" });
        AudioDevices.sources.forEach(function (d) { out.push({ kind: "device", d: d, sink: false, key: "dev:" + d.id }); });
        if (AudioDevices.sources.length === 0) out.push({ kind: "message", text: "Nessun ingresso audio", tone: "dim", key: "m-in" });
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && r.kind === "device"; }

    function move(delta) {
        var n = rows.length;
        if (n === 0) return;
        var i = list.currentIndex;
        for (var step = 0; step < n; step++) {
            i = (i + delta + n) % n;
            if (selectable(rows[i])) { list.currentIndex = i; return; }
        }
    }

    // Con l'elenco che cambia (scansioni) la selezione resta sulla stessa voce.
    onRowsChanged: {
        var idx = -1;
        for (var i = 0; i < rows.length; i++) if (rows[i].key === currentKey) { idx = i; break; }
        if (idx < 0) for (var j = 0; j < rows.length; j++) if (selectable(rows[j])) { idx = j; break; }
        list.currentIndex = idx;
    }

    // --- azioni -----------------------------------------------------------------------
    function current() { var r = rows[list.currentIndex]; return r && r.kind === "device" ? r.d : null; }

    onOpenChanged: if (open) keys.forceActiveFocus()

    // --- aspetto ------------------------------------------------------------------------
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 40); i++) h += rows[i].kind === "header" ? sectionHeight : Theme.rowHeight;
        return Math.min(h, maxRows * Theme.rowHeight + 2 * sectionHeight);
    }
    contentHeight: headerHeight + 1 + listHeight + Theme.padding + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) {
                Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var d = panel.current(); if (d) AudioDevices.makeDefault(d);
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                var d2 = panel.current(); if (d2) AudioDevices.changeVolume(d2, panel.step);
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                var d3 = panel.current(); if (d3) AudioDevices.changeVolume(d3, -panel.step);
            } else if (event.key === Qt.Key_M) {
                var d4 = panel.current(); if (d4) AudioDevices.toggleMute(d4);
            } else {
                return;
            }
            event.accepted = true;
        }

        // Intestazione
        Item {
            id: head
            width: parent.width
            height: panel.headerHeight
            BarText {
                anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: "Audio"
                font.bold: true
            }
            BarText {
                anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: Audio.available ? Math.round(Audio.volume * 100) + "%" + (Audio.muted ? " · muto" : "") : ""
                color: Theme.muted
            }
        }
        Rectangle { id: sepLine; anchors.top: head.bottom; width: parent.width; height: 1; color: Theme.border }

        // Elenco
        ListView {
            id: list
                        anchors { top: sepLine.bottom; topMargin: Theme.padding / 2; left: parent.left; right: parent.right }
            height: panel.listHeight
            model: panel.rows
            clip: true
            currentIndex: -1
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: panel.currentKey = (currentIndex >= 0 && currentIndex < panel.rows.length) ? panel.rows[currentIndex].key : ""

            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property var r: modelData
                readonly property bool isHeader: r.kind === "header"
                width: ListView.view.width
                height: isHeader ? panel.sectionHeight : Theme.rowHeight
                color: ListView.isCurrentItem && panel.selectable(r) ? Theme.border : "transparent"

                // sezione
                BarText {
                    visible: item.isHeader
                    anchors { left: parent.left; leftMargin: Theme.padding; bottom: parent.bottom; bottomMargin: 2 }
                    text: item.isHeader ? item.r.label.toUpperCase() : ""
                    color: Theme.dim
                    font.pixelSize: Theme.fontSize - 2
                    font.letterSpacing: 1
                }

                // messaggio
                BarText {
                    visible: item.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: item.r.kind === "message" ? item.r.text : ""
                    color: item.r.tone === "error" ? Theme.error : item.r.tone === "warn" ? Theme.warning : Theme.dim
                    elide: Text.ElideRight
                }

                // dispositivo
                Item {
                    visible: item.r.kind === "device"
                    anchors.fill: parent
                    BarIcon {
                        id: dicon
                        anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: item.r.kind !== "device" ? ""
                            : item.r.sink ? (item.r.d.muted ? Icons.volumeMuted : Icons.pick(Icons.volume, item.r.d.volume))
                            : (item.r.d.muted ? Icons.micOff : Icons.mic)
                        color: item.r.kind === "device" && item.r.d.isDefault && !item.r.d.muted ? Theme.accent : Theme.muted
                    }
                    BarText {
                        anchors { left: dicon.right; leftMargin: Theme.spacing; right: bar.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "device" ? item.r.d.name : ""
                        elide: Text.ElideRight
                        font.bold: item.r.kind === "device" && item.r.d.isDefault
                    }
                    // barra del volume
                    Rectangle {
                        id: bar
                        anchors { right: pct.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        width: 80
                        height: 4
                        radius: 2
                        color: Theme.border
                        Rectangle {
                            width: item.r.kind === "device" ? Math.min(1, item.r.d.volume) * parent.width : 0
                            height: parent.height
                            radius: 2
                            color: item.r.kind === "device" && item.r.d.muted ? Theme.muted : Theme.accent
                        }
                        MouseArea {
                            anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
                            onPressed: mouse => { if (item.r.kind === "device") AudioDevices.setVolume(item.r.d, mouse.x / width); }
                            onPositionChanged: mouse => { if (pressed && item.r.kind === "device") AudioDevices.setVolume(item.r.d, Math.max(0, Math.min(1, mouse.x / width))); }
                        }
                    }
                    BarText {
                        id: pct
                        width: 36
                        horizontalAlignment: Text.AlignRight
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "device" ? Math.round(item.r.d.volume * 100) + "%" : ""
                        color: Theme.muted
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: panel.selectable(item.r)
                    hoverEnabled: true
                    onEntered: list.currentIndex = item.index
                    onClicked: { list.currentIndex = item.index; if (item.r.kind === "device") AudioDevices.makeDefault(item.r.d); }
                }
            }
        }

        // Conferma "dimentica" e suggerimenti
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
                color: Theme.dim
                text: "Invio = predefinito · ←/→ = volume · M = muto · Esc = chiudi"
            }
        }
    }
}
