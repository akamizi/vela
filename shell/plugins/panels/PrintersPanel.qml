// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello delle stampanti (D-046): stampanti CUPS con stato e predefinita, e coda dei lavori. Lo stato si rilegge ogni 4 s solo
// con il pannello aperto. ↑/↓ = scorri · Invio = predefinita (stampante) o annulla (lavoro) · Spazio = ferma/riprendi la stampante ·
// Canc = annulla tutti i lavori della stampante (o il lavoro) · Maiusc+Canc = rimuove la stampante (con conferma) · Esc chiude.
// In fondo: ricerca dei dispositivi e aggiunta per indirizzo (IPP Everywhere, senza driver).
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "printers"
    cardWidth: Math.max(Theme.panelWidth, 460)

    readonly property int footerHeight: 28
    readonly property int maxListHeight: 12 * Theme.rowHeight
    property string currentKey: ""
    property bool addPrompt: false        // campo per l'indirizzo della stampante
    property string removeAsk: ""         // stampante di cui si attende la conferma di rimozione

    function stateText(p) {
        return p.state === "printing" ? I18n.tr("in stampa") : p.state === "disabled" ? I18n.tr("ferma") : I18n.tr("pronta");
    }
    function sizeText(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"; }

    function buildRows() {
        var out = [];
        if (!Printers.known) {
            out.push({ kind: "message", text: I18n.tr("Lettura in corso…"), key: "m-wait" });
            return out;
        }
        if (!Printers.schedulerUp) {
            out.push({ kind: "message", text: I18n.tr("Il servizio di stampa (cupsd) non è attivo"), warn: true, key: "m-down" });
            return out;
        }
        out.push({ kind: "header", label: I18n.tr("Stampanti"), key: "h-printers" });
        if (Printers.printers.length === 0) out.push({ kind: "message", text: I18n.tr("Nessuna stampante configurata"), key: "m-none" });
        Printers.printers.forEach(function (p) {
            out.push({ kind: "printer", p: p, label: p.name, key: "p:" + p.name });
            if (p.state === "disabled" && p.reason !== "" && p.reason !== "-")
                out.push({ kind: "message", text: p.reason === "Paused" ? I18n.tr("In pausa") : p.reason, key: "r:" + p.name });
        });
        if (Printers.jobs.length > 0) {
            out.push({ kind: "header", label: I18n.tr("Lavori in coda"), key: "h-jobs" });
            Printers.jobs.forEach(function (j) { out.push({ kind: "job", j: j, label: j.id, key: "j:" + j.id }); });
        }
        if (panel.removeAsk !== "")
            out.push({ kind: "message", text: I18n.tr("Rimuovere %1? Invio conferma, Esc annulla", panel.removeAsk), warn: true, key: "m-rm" });
        out.push({ kind: "header", label: I18n.tr("Aggiungi una stampante"), key: "h-add" });
        out.push({ kind: "action", act: "scan", label: Printers.scanning ? I18n.tr("Ricerca in corso…") : I18n.tr("Cerca stampanti"), key: "a:scan" });
        Printers.devices.forEach(function (d) { out.push({ kind: "device", d: d, label: d.info || d.uri, key: "d:" + d.uri }); });
        if (Printers.scanned && !Printers.scanning && Printers.devices.length === 0)
            out.push({ kind: "message", text: I18n.tr("Nessuna stampante trovata (per la ricerca in rete serve avahi)"), key: "m-nodev" });
        out.push({ kind: "action", act: "address", label: I18n.tr("Aggiungi per indirizzo…"), key: "a:addr" });
        if (Printers.error !== "") out.push({ kind: "message", text: Printers.error, warn: true, key: "m-err" });
        else if (Printers.printers.length > 0 && !Printers.admin)
            out.push({ kind: "message", text: I18n.tr("Sola lettura per fermare le stampanti: serve il gruppo lpadmin"), key: "m-admin" });
        return out;
    }
    readonly property var rows: buildRows()

    function selectable(r) { return r && (r.kind === "printer" || r.kind === "job" || r.kind === "action" || r.kind === "device"); }
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

    function activate(r) {
        if (!r) return;
        if (removeAsk !== "") { var n = removeAsk; removeAsk = ""; Printers.removePrinter(n); return; }
        if (r.kind === "action") {
            if (r.act === "scan") Printers.scan();
            else { addPrompt = true; address.text = ""; address.forceActiveFocus(); }
        } else if (r.kind === "device") Printers.addPrinter(r.d.uri, r.d.info);
        else if (r.kind === "printer") Printers.setDefault(r.p.name);
        else if (r.kind === "job") Printers.cancelJob(r.j.id);
    }
    function submitAddress() {
        var uri = Printers.normalizeAddress(address.text);
        closePrompt();
        if (uri === "") Printers.error = I18n.tr("Indirizzo non valido");
        else Printers.addPrinter(uri, "");
    }
    function closePrompt() { addPrompt = false; keys.forceActiveFocus(); }
    function cancelRow(r) {
        if (!r) return;
        if (r.kind === "printer") Printers.cancelAll(r.p.name);
        else if (r.kind === "job") Printers.cancelJob(r.j.id);
    }

    onOpenChanged: {
        if (open) {
            Printers.refresh();
            currentKey = "";
            addPrompt = false;
            removeAsk = "";
            keys.forceActiveFocus();
        }
    }
    Timer { interval: 4000; running: panel.open; repeat: true; onTriggered: Printers.refresh() }

    property real listHeight: {
        if (addPrompt) return 2 * Theme.rowHeight + Theme.padding;
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
            var r = panel.current();
            if (event.key === Qt.Key_Escape) {
                if (panel.removeAsk !== "") panel.removeAsk = ""; else Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Space && r && r.kind === "printer") {
                Printers.togglePause(r.p.name, r.p.state);
            } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                if (r && r.kind === "printer") panel.removeAsk = r.p.name;
            } else if (event.key === Qt.Key_Delete) {
                panel.cancelRow(r);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                panel.activate(r);
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: Icons.printer
            iconColor: Printers.schedulerUp ? Theme.accent : Theme.muted
            title: I18n.tr("Stampanti")
            meta: !Printers.known ? "" : !Printers.schedulerUp ? I18n.tr("servizio fermo")
                : Printers.printers.length === 0 ? I18n.tr("nessuna stampante")
                : Printers.jobs.length === 1 ? I18n.tr("1 lavoro in coda")
                : Printers.jobs.length > 1 ? I18n.tr("%1 lavori in coda", String(Printers.jobs.length))
                : I18n.tr("nessun lavoro in coda")
            detail: Printers.defaultName !== "" ? Printers.defaultName : ""
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        // Indirizzo della stampante (URI o nome/IP)
        Item {
            visible: panel.addPrompt
            anchors { top: sep.bottom; left: parent.left; right: parent.right; margins: Theme.padding }
            height: panel.listHeight - Theme.padding
            BarText {
                id: addLabel
                width: parent.width
                text: I18n.tr("Indirizzo della stampante (nome, IP o URI)")
                elide: Text.ElideRight
                color: Theme.muted
            }
            Rectangle {
                anchors { top: addLabel.bottom; topMargin: Theme.spacing; left: parent.left; right: parent.right }
                height: Theme.rowHeight - 4
                color: Theme.background
                border.color: Theme.accent
                radius: Theme.radius
                TextInput {
                    id: address
                    enabled: panel.addPrompt     // da disabilitato non tiene il focus: i tasti tornano all'elenco
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    verticalAlignment: TextInput.AlignVCenter
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.submitAddress();
                        else if (event.key === Qt.Key_Escape) panel.closePrompt();
                        else return;
                        event.accepted = true;
                    }
                }
            }
        }

        ListView {
            id: list
            visible: !panel.addPrompt
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
                width: ListView.view.width
                height: r.kind === "header" ? 28 : Theme.rowHeight

                PanelSectionHeader { visible: entry.r.kind === "header"; text: entry.r.kind === "header" ? entry.r.label : "" }

                BarText {
                    visible: entry.r.kind === "message"
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                    text: entry.r.kind === "message" ? entry.r.text : ""
                    color: entry.r.kind === "message" && entry.r.warn ? Theme.warning : Theme.dim
                    elide: Text.ElideRight
                }

                PanelRow {
                    visible: panel.selectable(entry.r)
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    hasCursor: ListView.isCurrentItem
                    selected: entry.r.kind === "printer" && entry.r.p.name === Printers.defaultName
                    icon: entry.r.kind === "printer" || entry.r.kind === "device" ? Icons.printer
                        : entry.r.kind === "action" ? Icons.check : Icons.duplicate
                    iconColor: entry.r.kind === "printer" && entry.r.p.state !== "disabled" ? Theme.accent : Theme.muted
                    title: entry.r.kind === "printer" ? entry.r.p.name
                         : entry.r.kind === "job" ? entry.r.j.id + " · " + entry.r.j.user
                         : entry.r.kind === "device" || entry.r.kind === "action" ? entry.r.label : ""
                    bold: entry.r.kind === "printer" && entry.r.p.name === Printers.defaultName
                    trailingText: entry.r.kind === "printer"
                        ? (entry.r.p.name === Printers.defaultName ? I18n.tr("predefinita") + " · " : "") + panel.stateText(entry.r.p)
                        : entry.r.kind === "job" ? panel.sizeText(entry.r.j.size)
                        : entry.r.kind === "device" ? entry.r.d.make : ""
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
                color: Theme.dim
                text: panel.addPrompt ? I18n.tr("Invio aggiunge · Esc annulla")
                    : panel.removeAsk !== "" ? I18n.tr("Invio conferma la rimozione · Esc annulla")
                    : panel.current() && panel.current().kind === "printer" ? I18n.tr("Invio predefinita · Spazio ferma/riprendi · Canc annulla i lavori · Maiusc+Canc rimuove · Esc chiude")
                    : panel.current() && panel.current().kind === "device" ? I18n.tr("Invio aggiunge la stampante (senza driver) · Esc chiude")
                    : panel.current() && panel.current().kind === "job" ? I18n.tr("Invio o Canc annulla il lavoro · Esc chiude")
                    : I18n.tr("Esc chiude")
            }
        }
    }
}
