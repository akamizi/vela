// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello rete: Wi-Fi (elenco, connessione, password per reti nuove), cavo e VPN.
// Invio = connetti/disconnetti · Canc = dimentica la rete · Esc = indietro/chiude.
// Le credenziali non si salvano qui: la password passa a NetworkManager e il campo viene svuotato.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "network"

    readonly property int headerHeight: Theme.rowHeight
    readonly property int sectionHeight: 26
    readonly property int footerHeight: 28
    readonly property int maxRows: 12

    property var prompt: null          // rete in attesa di password
    property var forgetting: null      // rete in attesa di conferma "dimentica"
    property string note: ""           // avviso locale (es. rete aziendale)
    property string currentKey: ""

    Timer { id: noteClear; interval: 8000; onTriggered: panel.note = "" }

    // --- elenco -------------------------------------------------------------------
    function buildRows() {
        var out = [];
        out.push({ kind: "header", label: "Wi-Fi", key: "h-wifi" });
        if (Wifi.available) {
            out.push({ kind: "wifiswitch", key: "wifiswitch" });
            if (!Wifi.hardwareEnabled) {
                out.push({ kind: "message", text: "Wi-Fi disattivato dall'hardware (interruttore o rfkill)", tone: "warn", key: "m-hw" });
            } else if (Wifi.enabled) {
                var nets = Wifi.networks;
                nets.forEach(function (e) { out.push({ kind: "wifi", e: e, key: "wifi:" + e.name }); });
                if (nets.length === 0) out.push({ kind: "message", text: "Ricerca delle reti…", tone: "dim", key: "m-scan" });
            }
        } else {
            out.push({ kind: "message", text: "Nessuna scheda Wi-Fi", tone: "dim", key: "m-nowifi" });
        }
        if (Wifi.error !== "")
            out.push({ kind: "message", text: (Wifi.errorNetwork ? Wifi.errorNetwork + ": " : "") + Wifi.error, tone: "error", key: "m-err" });
        if (note !== "") out.push({ kind: "message", text: note, tone: "warn", key: "m-note" });

        if (Wifi.wired.length > 0) {
            out.push({ kind: "header", label: "Cavo", key: "h-wired" });
            Wifi.wired.forEach(function (w) { out.push({ kind: "wired", w: w, key: "wired:" + w.name }); });
        }
        if (Vpn.known.length > 0) {
            out.push({ kind: "header", label: "VPN", key: "h-vpn" });
            Vpn.known.forEach(function (n) { out.push({ kind: "vpn", name: n, active: Vpn.isActive(n), key: "vpn:" + n }); });
        }
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && (r.kind === "wifiswitch" || r.kind === "wifi" || r.kind === "vpn"); }

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
        if (r.kind === "wifiswitch") { Wifi.setEnabled(!Wifi.enabled); return; }
        if (r.kind === "vpn") { Vpn.toggleOne(r.name); return; }
        if (r.kind !== "wifi") return;
        var e = r.e;
        if (e.connecting) return;
        if (e.connected) Wifi.disconnect(e);
        else if (e.known) Wifi.connect(e);
        else if (e.enterprise) { note = "Rete aziendale: configurarla con nm-connection-editor"; noteClear.restart(); }
        else if (e.secured) startPrompt(e);
        else Wifi.connect(e);
    }

    function startPrompt(e) {
        prompt = e;
        password.text = "";
        password.forceActiveFocus();
    }

    function submitPassword() {
        var e = prompt, pw = password.text;
        password.text = "";            // non lasciare la password in nessun campo
        prompt = null;
        keys.forceActiveFocus();
        if (e && pw !== "") Wifi.connectWithPassword(e, pw);
    }

    function cancelPrompt() {
        password.text = "";
        prompt = null;
        keys.forceActiveFocus();
    }

    // Dopo una password rifiutata si riapre il campo per quella rete.
    Connections {
        target: Wifi
        function onNeedsPasswordChanged() {
            if (!Wifi.needsPassword || !panel.open) return;
            var nets = Wifi.networks;
            for (var i = 0; i < nets.length; i++)
                if (nets[i].name === Wifi.errorNetwork && nets[i].secured && !nets[i].enterprise) { panel.startPrompt(nets[i]); return; }
        }
    }

    onOpenChanged: {
        if (open) {
            prompt = null; forgetting = null; note = "";
            Wifi.clearError();
            Wifi.scan(true);
            keys.forceActiveFocus();
        } else {
            Wifi.scan(false);
            password.text = "";
            prompt = null;
        }
    }

    // --- aspetto ------------------------------------------------------------------------
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 40); i++) h += rows[i].kind === "header" ? sectionHeight : Theme.rowHeight;
        return Math.min(h, maxRows * Theme.rowHeight + 2 * sectionHeight);
    }
    contentHeight: headerHeight + 1 + (prompt ? Theme.rowHeight * 2 + Theme.padding : listHeight + Theme.padding) + footerHeight

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
                if (panel.forgetting) { Wifi.forget(panel.forgetting); panel.forgetting = null; }
                else panel.activate(panel.rows[list.currentIndex]);
            } else if (event.key === Qt.Key_Delete) {
                var r = panel.rows[list.currentIndex];
                if (r && r.kind === "wifi" && r.e.known) panel.forgetting = r.e;
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
                text: "Rete"
                font.bold: true
            }
            BarText {
                anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: NetworkStatus.summary.kind === "none" ? "disconnesso" : NetworkStatus.summary.name || NetworkStatus.summary.device
                color: Theme.muted
            }
        }
        Rectangle { id: sepLine; anchors.top: head.bottom; width: parent.width; height: 1; color: Theme.border }

        // Richiesta di password
        Item {
            visible: panel.prompt !== null
            anchors { top: sepLine.bottom; left: parent.left; right: parent.right; margins: Theme.padding }
            height: Theme.rowHeight * 2
            BarText {
                id: promptLabel
                width: parent.width
                text: panel.prompt ? "Password per " + panel.prompt.name : ""
                elide: Text.ElideRight
                color: Theme.muted
            }
            Rectangle {
                anchors { top: promptLabel.bottom; topMargin: Theme.spacing / 2; left: parent.left; right: parent.right }
                height: Theme.rowHeight - 4
                color: Theme.background
                border.color: Theme.accent
                radius: Theme.radius
                TextInput {
                    id: password
                    enabled: panel.prompt !== null     // da disabilitato non tiene il focus: i tasti tornano all'elenco
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.submitPassword();
                        else if (event.key === Qt.Key_Escape) panel.cancelPrompt();
                        else return;
                        event.accepted = true;
                    }
                }
            }
        }

        // Elenco
        ListView {
            id: list
            visible: panel.prompt === null
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

                // interruttore Wi-Fi
                Item {
                    visible: item.r.kind === "wifiswitch"
                    anchors.fill: parent
                    BarText { anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter } text: "Wi-Fi" }
                    BarText {
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: Wifi.enabled ? "acceso" : "spento"
                        color: Wifi.enabled ? Theme.accent : Theme.muted
                    }
                }

                // rete Wi-Fi
                Item {
                    visible: item.r.kind === "wifi"
                    anchors.fill: parent
                    BarIcon {
                        id: sig
                        anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "wifi" ? Icons.pick(Icons.wifi, item.r.e.signal) : ""
                        color: item.r.kind === "wifi" && item.r.e.connected ? Theme.accent : Theme.foreground
                    }
                    BarText {
                        anchors { left: sig.right; leftMargin: Theme.spacing; right: state.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "wifi" ? item.r.e.name : ""
                        elide: Text.ElideRight
                        font.bold: item.r.kind === "wifi" && item.r.e.connected
                    }
                    Row {
                        id: state
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        spacing: Theme.gap
                        BarText {
                            text: item.r.kind !== "wifi" ? "" : item.r.e.connecting ? "connessione…" : item.r.e.connected ? "connessa" : item.r.e.known ? "salvata" : ""
                            color: item.r.kind === "wifi" && item.r.e.connected ? Theme.accent : Theme.muted
                        }
                        BarIcon { visible: item.r.kind === "wifi" && item.r.e.secured; text: Icons.lock; color: Theme.muted; font.pixelSize: Theme.fontSize }
                    }
                }

                // cavo
                Item {
                    visible: item.r.kind === "wired"
                    anchors.fill: parent
                    BarIcon { id: eth; anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter } text: Icons.ethernet }
                    BarText { anchors { left: eth.right; leftMargin: Theme.spacing; verticalCenter: parent.verticalCenter } text: item.r.kind === "wired" ? item.r.w.name : "" }
                    BarText {
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: item.r.kind !== "wired" ? "" : item.r.w.connected ? "connesso" : item.r.w.link ? "collegato" : "scollegato"
                        color: item.r.kind === "wired" && item.r.w.connected ? Theme.accent : Theme.muted
                    }
                }

                // VPN
                Item {
                    visible: item.r.kind === "vpn"
                    anchors.fill: parent
                    BarIcon { id: vp; anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter } text: Icons.vpn; color: item.r.kind === "vpn" && item.r.active ? Theme.accent : Theme.muted }
                    BarText {
                        anchors { left: vp.right; leftMargin: Theme.spacing; right: vstate.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "vpn" ? item.r.name : ""
                        elide: Text.ElideRight
                    }
                    BarText {
                        id: vstate
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: item.r.kind === "vpn" && item.r.active ? "attiva" : ""
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: panel.selectable(item.r)
                    hoverEnabled: true
                    onEntered: list.currentIndex = item.index
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
                    : panel.prompt ? "Invio = connetti · Esc = annulla"
                    : "Invio = connetti/disconnetti · Canc = dimentica · Esc = chiudi"
            }
        }
    }
}
