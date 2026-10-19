// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello rete (D-023): intestazione con interruttore Wi-Fi, reti Wi-Fi, cavo e VPN.
// Invio = connetti/disconnetti · Spazio = accendi/spegni il Wi-Fi · Canc = dimentica la rete · Esc = indietro/chiude.
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
    cardWidth: Math.max(Theme.panelWidth, 400)

    readonly property int footerHeight: 28
    readonly property int maxListHeight: 12 * Theme.rowHeight

    property var prompt: null          // rete in attesa di password
    property var forgetting: null      // rete in attesa di conferma "dimentica"
    property string note: ""           // avviso locale (es. rete aziendale)
    property string currentKey: ""

    Timer { id: noteClear; interval: 8000; onTriggered: panel.note = "" }

    // --- elenco -------------------------------------------------------------------
    function buildRows() {
        var out = [];
        out.push({ kind: "header", label: I18n.tr("Wi-Fi"), key: "h-wifi" });
        if (Wifi.available) {
            if (!Wifi.hardwareEnabled) {
                out.push({ kind: "message", text: I18n.tr("Wi-Fi disattivato dall'hardware (interruttore o rfkill)"), tone: "warn", key: "m-hw" });
            } else if (!Wifi.enabled) {
                out.push({ kind: "message", text: I18n.tr("Wi-Fi spento: premi Spazio per accenderlo"), tone: "dim", key: "m-off" });
            } else {
                var nets = Wifi.networks;
                nets.forEach(function (e) { out.push({ kind: "wifi", e: e, key: "wifi:" + e.name }); });
                if (nets.length === 0) out.push({ kind: "message", text: I18n.tr("Ricerca delle reti…"), tone: "dim", key: "m-scan" });
            }
        } else {
            out.push({ kind: "message", text: I18n.tr("Nessuna scheda Wi-Fi"), tone: "dim", key: "m-nowifi" });
        }
        if (Wifi.error !== "")
            out.push({ kind: "message", text: (Wifi.errorNetwork ? Wifi.errorNetwork + ": " : "") + Wifi.error, tone: "error", key: "m-err" });
        if (note !== "") out.push({ kind: "message", text: note, tone: "warn", key: "m-note" });

        if (Wifi.wired.length > 0) {
            out.push({ kind: "header", label: I18n.tr("Cavo"), key: "h-wired" });
            Wifi.wired.forEach(function (w) { out.push({ kind: "wired", w: w, key: "wired:" + w.name }); });
        }
        if (Vpn.known.length > 0) {
            out.push({ kind: "header", label: I18n.tr("VPN"), key: "h-vpn" });
            Vpn.known.forEach(function (n) { out.push({ kind: "vpn", name: n, active: Vpn.isActive(n), key: "vpn:" + n }); });
        }
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && (r.kind === "wifi" || r.kind === "vpn"); }
    function current() { return rows[list.currentIndex] || null; }

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
    // Con l'elenco che cambia (scansioni) la selezione resta sulla stessa voce.
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
        if (!r) return;
        if (r.kind === "vpn") { Vpn.toggleOne(r.name); return; }
        if (r.kind !== "wifi") return;
        var e = r.e;
        if (e.connecting) return;
        if (e.connected) Wifi.disconnect(e);
        else if (e.known) Wifi.connect(e);
        else if (e.enterprise) { note = I18n.tr("Rete aziendale: configurarla con nm-connection-editor"); noteClear.restart(); }
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
            prompt = null; forgetting = null; note = ""; currentKey = "";
            Wifi.clearError();
            Wifi.scan(true);
            for (var i = 0; i < rows.length; i++) if (selectable(rows[i])) { select(i); break; }
            keys.forceActiveFocus();
        } else {
            Wifi.scan(false);
            password.text = "";
            prompt = null;
        }
    }

    // --- aspetto ------------------------------------------------------------------------
    readonly property var net: NetworkStatus.summary
    readonly property int vpnActive: Vpn.active.length
    property real listHeight: {
        var h = 0;
        for (var i = 0; i < Math.min(rows.length, 60); i++) h += rows[i].kind === "header" ? 28 : Theme.rowHeight;
        return Math.min(h + Theme.spacing, maxListHeight);
    }
    readonly property real promptHeight: Theme.rowHeight * 2 + Theme.padding * 2
    contentHeight: hero.implicitHeight + 1 + (prompt ? promptHeight : listHeight) + footerHeight

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
                if (Wifi.available) Wifi.setEnabled(!Wifi.enabled);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (panel.forgetting) { Wifi.forget(panel.forgetting); panel.forgetting = null; }
                else panel.activate(panel.current());
            } else if (event.key === Qt.Key_Delete) {
                var r = panel.current();
                if (r && r.kind === "wifi" && r.e.known) panel.forgetting = r.e;
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: panel.net.kind === "wifi" ? Icons.pick(Icons.wifi, panel.net.signal)
                : panel.net.kind === "ethernet" ? Icons.ethernet : Icons.wifiOff
            iconColor: panel.net.kind === "none" ? Theme.muted : Theme.accent
            title: I18n.tr("Rete")
            meta: panel.net.kind === "none" ? I18n.tr("disconnesso") : (panel.net.name || panel.net.device)
            detail: panel.vpnActive > 0 ? "VPN" + (panel.vpnActive > 1 ? " ×" + panel.vpnActive : "") : ""
            trailing: Component {
                ToggleSwitch {
                    visible: Wifi.available && Wifi.hardwareEnabled
                    checked: Wifi.enabled
                    onToggled: Wifi.setEnabled(!Wifi.enabled)
                }
            }
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        // Richiesta di password
        Item {
            visible: panel.prompt !== null
            anchors { top: sep.bottom; left: parent.left; right: parent.right; margins: Theme.padding }
            height: panel.promptHeight - Theme.padding
            BarText {
                id: promptLabel
                width: parent.width
                text: panel.prompt ? I18n.tr("Password per %1", panel.prompt.name) : ""
                elide: Text.ElideRight
                color: Theme.muted
            }
            Rectangle {
                anchors { top: promptLabel.bottom; topMargin: Theme.spacing; left: parent.left; right: parent.right }
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

        ListView {
            id: list
            visible: panel.prompt === null
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
                // Durante il ricalcolo dell'elenco un delegato può restare senza dati: tutto passa da qui.
                readonly property var wifi: modelData && modelData.kind === "wifi" ? modelData.e : null
                readonly property var vpn: modelData && modelData.kind === "vpn" ? modelData : null
                readonly property var wired: modelData && modelData.kind === "wired" ? modelData.w : null
                width: ListView.view.width
                height: r.kind === "header" ? 28 : Theme.rowHeight

                PanelSectionHeader { visible: entry.r.kind === "header"; text: entry.r.kind === "header" ? entry.r.label : "" }

                BarText {
                    visible: entry.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: entry.r.kind === "message" ? entry.r.text : ""
                    color: entry.r.tone === "error" ? Theme.error : entry.r.tone === "warn" ? Theme.warning : Theme.dim
                    elide: Text.ElideRight
                }

                // rete Wi-Fi
                PanelRow {
                    visible: entry.r.kind === "wifi"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    icon: entry.wifi ? Icons.pick(Icons.wifi, entry.wifi.signal) : ""
                    iconColor: entry.wifi && entry.wifi.connected ? Theme.accent : Theme.foreground
                    title: entry.wifi ? entry.wifi.name : ""
                    bold: entry.wifi ? entry.wifi.connected : false
                    selected: entry.wifi ? entry.wifi.connected : false
                    trailingText: !entry.wifi ? "" : entry.wifi.connecting ? I18n.tr("connessione…") : entry.wifi.connected ? I18n.tr("connessa") : entry.wifi.known ? I18n.tr("salvata") : ""
                    trailingColor: entry.wifi && entry.wifi.connected ? Theme.accent : Theme.muted
                    trailing: Component {
                        BarIcon { visible: entry.wifi && entry.wifi.secured; text: Icons.lock; color: Theme.muted; font.pixelSize: Theme.fontSize }
                    }
                    onMoved: panel.select(entry.index)
                    onClicked: { panel.select(entry.index); panel.activate(entry.r); }
                }

                // cavo (solo informazione)
                PanelRow {
                    visible: entry.r.kind === "wired"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    icon: Icons.ethernet
                    iconColor: entry.wired && entry.wired.connected ? Theme.accent : Theme.muted
                    title: entry.wired ? entry.wired.name : ""
                    trailingText: !entry.wired ? "" : entry.wired.connected ? I18n.tr("connesso") : entry.wired.link ? I18n.tr("collegato") : I18n.tr("scollegato")
                    trailingColor: entry.wired && entry.wired.connected ? Theme.accent : Theme.muted
                    enabled: false
                }

                // VPN, con interruttore
                PanelRow {
                    visible: entry.r.kind === "vpn"
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    icon: Icons.vpn
                    iconColor: entry.vpn && entry.vpn.active ? Theme.accent : Theme.muted
                    title: entry.vpn ? entry.vpn.name : ""
                    trailing: Component {
                        ToggleSwitch { interactive: false; checked: entry.vpn ? entry.vpn.active : false }
                    }
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
                color: panel.forgetting ? Theme.warning : Theme.dim
                text: panel.forgetting ? I18n.tr("Dimenticare «%1»? Invio = sì, Esc = no", panel.forgetting.name)
                    : panel.prompt ? I18n.tr("Invio = connetti · Esc = annulla")
                    : I18n.tr("Invio connetti · Spazio Wi-Fi on/off · Canc dimentica")
            }
        }
    }
}
