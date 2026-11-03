// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello audio (D-023): intestazione con l'uscita predefinita e il muto, uscite e ingressi con volume per dispositivo.
// Le quattro sezioni (Uscite, Ingressi, Applicazioni, Registrazione) si richiudono: Invio o clic sull'intestazione, ←/→ sull'intestazione.
// Invio = rendi predefinito · ←/→ = volume · M = muto · Spazio = muto dell'uscita predefinita · Esc = chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "audio"
    cardWidth: Math.max(Theme.panelWidth, 420)

    readonly property int footerHeight: 28
    readonly property int maxListHeight: 12 * Theme.rowHeight

    property string currentKey: ""
    readonly property real step: Config.shell.audio.step * 2.5   // passo del pannello: 5% col valore di default

    // Sezioni richiuse (per chiave dell'intestazione): vale finché il pannello è aperto, alla riapertura è tutto aperto.
    property var folded: ({})
    function isOpen(key) { return folded[key] !== true; }
    function setOpen(key, v) {
        var f = {};
        for (var k in folded) f[k] = folded[k];
        f[key] = !v;
        folded = f;
    }

    // --- elenco -------------------------------------------------------------------
    function buildRows() {
        var out = [];
        function head(key, label, count) { out.push({ kind: "head", key: key, label: label, count: count }); }
        head("h-out", I18n.tr("Uscite"), AudioDevices.sinks.length);
        if (isOpen("h-out")) {
            AudioDevices.sinks.forEach(function (d) { out.push({ kind: "device", d: d, sink: true, key: "dev:" + d.id }); });
            if (AudioDevices.sinks.length === 0) out.push({ kind: "message", text: I18n.tr("Nessuna uscita audio"), key: "m-out" });
        }
        head("h-in", I18n.tr("Ingressi"), AudioDevices.sources.length);
        if (isOpen("h-in")) {
            AudioDevices.sources.forEach(function (d) { out.push({ kind: "device", d: d, sink: false, key: "dev:" + d.id }); });
            if (AudioDevices.sources.length === 0) out.push({ kind: "message", text: I18n.tr("Nessun ingresso audio"), key: "m-in" });
        }
        head("h-apps", I18n.tr("Applicazioni"), AudioDevices.playbackApps.length);
        if (isOpen("h-apps")) {
            AudioDevices.playbackApps.forEach(function (g) { out.push({ kind: "app", g: g, rec: false, key: "app:" + g.key }); });
            if (AudioDevices.playbackApps.length === 0) out.push({ kind: "message", text: I18n.tr("Nessuna applicazione sta riproducendo"), key: "m-apps" });
        }
        // La registrazione compare solo se c'è qualcuno che registra
        if (AudioDevices.recordingApps.length > 0) {
            head("h-rec", I18n.tr("Registrazione"), AudioDevices.recordingApps.length);
            if (isOpen("h-rec"))
                AudioDevices.recordingApps.forEach(function (g) { out.push({ kind: "app", g: g, rec: true, key: "rec:" + g.key }); });
        }
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && (r.kind === "device" || r.kind === "app" || r.kind === "head"); }
    function currentRow() { return rows[list.currentIndex] || null; }
    function current() { var r = currentRow(); return r && r.kind === "device" ? r.d : null; }
    function currentApp() { var r = currentRow(); return r && r.kind === "app" ? r.g : null; }

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

    onOpenChanged: {
        if (open) {
            currentKey = "";
            for (var i = 0; i < rows.length; i++) if (selectable(rows[i])) { select(i); break; }
            keys.forceActiveFocus();
        }
    }

    // --- aspetto ------------------------------------------------------------------------
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 60); i++) h += Theme.rowHeight;
        return Math.min(h + Theme.spacing, maxListHeight);
    }
    contentHeight: hero.implicitHeight + 1 + listHeight + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            var d = panel.current(), ap = panel.currentApp(), hd = panel.currentRow();
            if (hd && hd.kind !== "head") hd = null;
            if (event.key === Qt.Key_Escape) {
                Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Space) {
                Audio.toggleMute();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (d) AudioDevices.makeDefault(d);
                else if (hd) panel.setOpen(hd.key, !panel.isOpen(hd.key));
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                if (d) AudioDevices.changeVolume(d, panel.step);
                else if (ap) AudioDevices.changeAppVolume(ap, panel.step);
                else if (hd) panel.setOpen(hd.key, true);
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                if (d) AudioDevices.changeVolume(d, -panel.step);
                else if (ap) AudioDevices.changeAppVolume(ap, -panel.step);
                else if (hd) panel.setOpen(hd.key, false);
            } else if (event.key === Qt.Key_M) {
                if (d) AudioDevices.toggleMute(d);
                else if (ap) AudioDevices.toggleAppMute(ap);
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: !Audio.available ? Icons.volumeMuted : Audio.muted ? Icons.volumeMuted : Icons.pick(Icons.volume, Audio.volume)
            iconColor: Audio.available && !Audio.muted ? Theme.accent : Theme.muted
            title: I18n.tr("Audio")
            meta: Audio.available ? Audio.deviceName : I18n.tr("nessuna uscita")
            detail: Audio.available ? Math.round(Audio.volume * 100) + "%" + (Audio.muted ? " · " + I18n.tr("muto") : "") : ""
            trailing: Component {
                ToggleSwitch {
                    visible: Audio.available
                    checked: !Audio.muted
                    onToggled: Audio.toggleMute()
                }
            }
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
                // Durante il ricalcolo dell'elenco il delegato può restare senza dati: tutto passa da qui.
                readonly property var dv: modelData && modelData.kind === "device" ? modelData.d : null
                width: ListView.view.width
                readonly property var ag: modelData && modelData.kind === "app" ? modelData.g : null
                height: Theme.rowHeight

                // intestazione di sezione richiudibile
                PanelRow {
                    visible: entry.r.kind === "head"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    icon: entry.r.kind === "head" && panel.isOpen(entry.r.key) ? Icons.chevronDown : Icons.chevronRight
                    iconColor: Theme.muted
                    title: entry.r.kind === "head" ? entry.r.label : ""
                    titleColor: Theme.dim
                    bold: true
                    trailingText: entry.r.kind === "head" && !panel.isOpen(entry.r.key) ? String(entry.r.count) : ""
                    trailingColor: Theme.muted
                    onMoved: panel.select(entry.index)
                    onClicked: { panel.select(entry.index); if (entry.r.kind === "head") panel.setOpen(entry.r.key, !panel.isOpen(entry.r.key)); }
                }

                // una riga per applicazione: volume e muto di tutti i suoi flussi
                PanelRow {
                    visible: entry.r.kind === "app"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    icon: entry.ag === null ? "" : entry.r.rec ? (entry.ag.muted ? Icons.micOff : Icons.mic)
                        : (entry.ag.muted ? Icons.volumeMuted : Icons.pick(Icons.volume, entry.ag.volume))
                    iconColor: entry.ag !== null && !entry.ag.muted ? Theme.accent : Theme.muted
                    title: entry.ag ? entry.ag.name : ""
                    trailingText: entry.ag ? Math.round(Math.min(1, entry.ag.volume) * 100) + "%" : ""
                    trailing: Component {
                        PanelSlider {
                            implicitWidth: 100
                            value: entry.ag ? Math.min(1, entry.ag.volume) : 0
                            maxValue: 1
                            muted: entry.ag ? entry.ag.muted : false
                            onMoved: v => { if (entry.ag) AudioDevices.setAppVolume(entry.ag, v); }
                        }
                    }
                    onMoved: panel.select(entry.index)
                    onClicked: panel.select(entry.index)
                }

                BarText {
                    visible: entry.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: entry.r.kind === "message" ? entry.r.text : ""
                    color: Theme.dim
                }

                PanelRow {
                    visible: entry.r.kind === "device"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    selected: entry.r.kind === "device" && entry.r.d.isDefault
                    icon: entry.r.kind !== "device" ? ""
                        : entry.r.sink ? (entry.r.d.muted ? Icons.volumeMuted : Icons.pick(Icons.volume, entry.r.d.volume))
                        : (entry.r.d.muted ? Icons.micOff : Icons.mic)
                    iconColor: entry.r.kind === "device" && entry.r.d.isDefault && !entry.r.d.muted ? Theme.accent : Theme.muted
                    title: entry.r.kind === "device" ? entry.r.d.name : ""
                    bold: entry.r.kind === "device" && entry.r.d.isDefault
                    trailingText: entry.r.kind === "device" ? Math.round(entry.r.d.volume * 100) + "%" : ""
                    trailing: Component {
                        PanelSlider {
                            implicitWidth: 100
                            value: entry.dv ? entry.dv.volume : 0
                            maxValue: 1
                            muted: entry.dv ? entry.dv.muted : false
                            onMoved: v => { if (entry.dv) AudioDevices.setVolume(entry.dv, v); }
                        }
                    }
                    onMoved: panel.select(entry.index)
                    onClicked: { panel.select(entry.index); if (entry.r.kind === "device") AudioDevices.makeDefault(entry.r.d); }
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
                text: I18n.tr("Invio predefinito/apri-chiudi · ←/→ volume · M muto · Spazio muto uscita")
            }
        }
    }
}
