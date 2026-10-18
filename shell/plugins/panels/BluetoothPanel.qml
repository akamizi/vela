// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello Bluetooth (D-023): intestazione con interruttore, dispositivi accoppiati e trovati dalla scansione.
// Invio = connetti/disconnetti/accoppia · Spazio = accendi/spegni · Canc = dimentica · Esc = chiude.
// PIN e passkey non passano da qui: l'accoppiamento è gestito da BlueZ.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "bluetooth"

    readonly property int footerHeight: 28
    readonly property int maxListHeight: 12 * Theme.rowHeight

    property var forgetting: null      // dispositivo in attesa di conferma "dimentica"
    property string currentKey: ""

    // --- elenco (solo dispositivi e messaggi: l'interruttore sta nell'intestazione) --------------
    function buildRows() {
        var out = [];
        if (!BluetoothDevices.available) {
            out.push({ kind: "message", text: "Nessun adattatore Bluetooth", tone: "dim", key: "m-none" });
            return out;
        }
        if (BluetoothDevices.error !== "")
            out.push({ kind: "message", text: BluetoothDevices.error, tone: "error", key: "m-err" });
        if (!BluetoothDevices.enabled) {
            out.push({ kind: "message", text: "Bluetooth spento: premi Spazio per accenderlo", tone: "dim", key: "m-off" });
            return out;
        }
        var devs = BluetoothDevices.devices;
        var known = devs.filter(function (d) { return d.paired || d.connected; });
        var found = devs.filter(function (d) { return !(d.paired || d.connected); });
        if (known.length > 0) {
            out.push({ kind: "header", label: "Dispositivi", key: "h-known" });
            known.forEach(function (d) { out.push({ kind: "device", d: d, key: "dev:" + d.address }); });
        }
        out.push({ kind: "header", label: "Disponibili", key: "h-found" });
        found.forEach(function (d) { out.push({ kind: "device", d: d, key: "dev:" + d.address }); });
        if (found.length === 0)
            out.push({ kind: "message", text: "Ricerca dispositivi… (mettilo in modalità accoppiamento)", tone: "dim", key: "m-scan" });
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && r.kind === "device"; }
    function current() { return rows[list.currentIndex] || null; }

    // La selezione si ricorda per chiave: l'elenco cambia a ogni scansione.
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

    // --- azioni -----------------------------------------------------------------------
    function activate(r) {
        if (!r || r.kind !== "device") return;
        var d = r.d;
        if (d.connecting || d.pairing) return;
        if (d.connected) BluetoothDevices.disconnect(d);
        else if (d.paired) BluetoothDevices.connect(d);
        else BluetoothDevices.pair(d);
    }

    onOpenChanged: {
        if (open) {
            forgetting = null;
            currentKey = "";
            BluetoothDevices.error = "";
            BluetoothDevices.scan(true);
            for (var i = 0; i < rows.length; i++) if (selectable(rows[i])) { select(i); break; }
            keys.forceActiveFocus();
        } else {
            BluetoothDevices.stopScan();
        }
    }

    // La scansione parte anche se il Bluetooth viene acceso a pannello aperto.
    Connections {
        target: BluetoothDevices
        function onEnabledChanged() { if (panel.open) BluetoothDevices.scan(true); }
    }

    // --- aspetto ------------------------------------------------------------------------
    readonly property int connectedCount: BluetoothStatus.connected.length
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 60); i++) h += rows[i].kind === "header" ? 28 : Theme.rowHeight;
        return Math.min(h + Theme.spacing, maxListHeight);
    }
    contentHeight: hero.implicitHeight + 1 + listHeight + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) {
                if (panel.forgetting) panel.forgetting = null;
                else Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Space) {
                BluetoothDevices.setEnabled(!BluetoothDevices.enabled);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (panel.forgetting) { BluetoothDevices.forget(panel.forgetting); panel.forgetting = null; }
                else panel.activate(panel.current());
            } else if (event.key === Qt.Key_Delete) {
                var r = panel.current();
                if (r && r.kind === "device" && r.d.paired) panel.forgetting = r.d;
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: !BluetoothDevices.enabled ? Icons.bluetoothOff : panel.connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetooth
            iconColor: BluetoothDevices.enabled ? Theme.accent : Theme.muted
            title: "Bluetooth"
            meta: !BluetoothDevices.available ? "non disponibile" : !BluetoothDevices.enabled ? "spento" : "acceso"
            detail: panel.connectedCount > 0 ? panel.connectedCount + (panel.connectedCount === 1 ? " collegato" : " collegati") : ""
            trailing: Component {
                ToggleSwitch {
                    visible: BluetoothDevices.available
                    checked: BluetoothDevices.enabled
                    onToggled: BluetoothDevices.setEnabled(!BluetoothDevices.enabled)
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
                id: item
                required property var modelData
                required property int index
                readonly property var r: modelData
                width: ListView.view.width
                height: r.kind === "header" ? 28 : Theme.rowHeight

                PanelSectionHeader { visible: item.r.kind === "header"; text: item.r.kind === "header" ? item.r.label : "" }

                BarText {
                    visible: item.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: item.r.kind === "message" ? item.r.text : ""
                    color: item.r.tone === "error" ? Theme.error : Theme.dim
                    elide: Text.ElideRight
                }

                PanelRow {
                    visible: item.r.kind === "device"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    icon: item.r.kind === "device" && item.r.d.connected ? Icons.bluetoothConnected : Icons.bluetooth
                    iconColor: item.r.kind === "device" && item.r.d.connected ? Theme.accent : Theme.foreground
                    title: item.r.kind === "device" ? item.r.d.name : ""
                    bold: item.r.kind === "device" && item.r.d.connected
                    trailingText: {
                        if (item.r.kind !== "device") return "";
                        var d = item.r.d;
                        if (d.pairing) return "accoppiamento…";
                        if (d.connecting) return "connessione…";
                        if (d.connected) return d.battery >= 0 ? Math.round(d.battery * 100) + "%" : "connesso";
                        return d.paired ? "accoppiato" : "";
                    }
                    trailingColor: item.r.kind === "device" && item.r.d.connected ? Theme.accent : Theme.muted
                    onMoved: panel.select(item.index)
                    onClicked: { panel.select(item.index); panel.activate(item.r); }
                }
            }
        }

        // Suggerimenti e conferma "dimentica"
        Item {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: panel.footerHeight
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }
            BarText {
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize - 2
                color: panel.forgetting ? Theme.warning : Theme.dim
                text: panel.forgetting ? "Dimenticare «" + panel.forgetting.name + "»? Invio = sì, Esc = no"
                    : "Invio connetti · Spazio on/off · Canc dimentica"
            }
        }
    }
}
