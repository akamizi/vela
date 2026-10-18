// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello Bluetooth: interruttore, dispositivi accoppiati e dispositivi trovati dalla scansione.
// Invio = connetti/disconnetti/accoppia · Canc = dimentica · Esc = chiude.
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

    readonly property int headerHeight: Theme.rowHeight
    readonly property int sectionHeight: 26
    readonly property int footerHeight: 28
    readonly property int maxRows: 12

    property var forgetting: null      // dispositivo in attesa di conferma "dimentica"
    property string currentKey: ""

    // --- elenco -------------------------------------------------------------------
    function buildRows() {
        var out = [];
        out.push({ kind: "header", label: "Bluetooth", key: "h-bt" });
        if (!BluetoothDevices.available) {
            out.push({ kind: "message", text: "Nessun adattatore Bluetooth", tone: "dim", key: "m-none" });
            return out;
        }
        out.push({ kind: "btswitch", key: "btswitch" });
        if (BluetoothDevices.error !== "")
            out.push({ kind: "message", text: BluetoothDevices.error, tone: "error", key: "m-err" });
        if (!BluetoothDevices.enabled) return out;

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

    function selectable(r) { return r && (r.kind === "btswitch" || r.kind === "device"); }

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
    function activate(r) {
        if (!r) return;
        if (r.kind === "btswitch") { BluetoothDevices.setEnabled(!BluetoothDevices.enabled); return; }
        if (r.kind !== "device") return;
        var d = r.d;
        if (d.connecting || d.pairing) return;
        if (d.connected) BluetoothDevices.disconnect(d);
        else if (d.paired) BluetoothDevices.connect(d);
        else BluetoothDevices.pair(d);
    }

    onOpenChanged: {
        if (open) {
            forgetting = null;
            BluetoothDevices.error = "";
            BluetoothDevices.scan(true);
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
                if (panel.forgetting) panel.forgetting = null;
                else Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (panel.forgetting) { BluetoothDevices.forget(panel.forgetting); panel.forgetting = null; }
                else panel.activate(panel.rows[list.currentIndex]);
            } else if (event.key === Qt.Key_Delete) {
                var r = panel.rows[list.currentIndex];
                if (r && r.kind === "device" && r.d.paired) panel.forgetting = r.d;
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
                text: "Bluetooth"
                font.bold: true
            }
            BarText {
                anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: BluetoothStatus.connected.length > 0 ? BluetoothStatus.connected.length + " collegat" + (BluetoothStatus.connected.length === 1 ? "o" : "i") : ""
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

                // interruttore
                Item {
                    visible: item.r.kind === "btswitch"
                    anchors.fill: parent
                    BarText { anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter } text: "Bluetooth" }
                    BarText {
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: BluetoothDevices.enabled ? "acceso" : "spento"
                        color: BluetoothDevices.enabled ? Theme.accent : Theme.muted
                    }
                }

                // dispositivo
                Item {
                    visible: item.r.kind === "device"
                    anchors.fill: parent
                    BarIcon {
                        id: dicon
                        anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "device" && item.r.d.connected ? Icons.bluetoothConnected : Icons.bluetooth
                        color: item.r.kind === "device" && item.r.d.connected ? Theme.accent : Theme.foreground
                    }
                    BarText {
                        anchors { left: dicon.right; leftMargin: Theme.spacing; right: dstate.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "device" ? item.r.d.name : ""
                        elide: Text.ElideRight
                        font.bold: item.r.kind === "device" && item.r.d.connected
                    }
                    BarText {
                        id: dstate
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: {
                            if (item.r.kind !== "device") return "";
                            var d = item.r.d;
                            if (d.pairing) return "accoppiamento…";
                            if (d.connecting) return "connessione…";
                            if (d.connected) return d.battery >= 0 ? Math.round(d.battery * 100) + "%" : "connesso";
                            return d.paired ? "accoppiato" : "";
                        }
                        color: item.r.kind === "device" && item.r.d.connected ? Theme.accent : Theme.muted
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: panel.selectable(item.r)
                    hoverEnabled: true
                    onPositionChanged: list.currentIndex = item.index
                    onClicked: { list.currentIndex = item.index; panel.activate(item.r); }
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
                color: panel.forgetting ? Theme.warning : Theme.dim
                text: panel.forgetting ? "Dimenticare «" + panel.forgetting.name + "»? Invio = sì, Esc = no"
                    : "Invio = connetti/accoppia · Canc = dimentica · Esc = chiudi"
            }
        }
    }
}
