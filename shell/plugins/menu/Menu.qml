// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Menu/launcher unico: voci dichiarative + applicazioni, con ricerca fuzzy e navigazione da tastiera.
//   Invio = esegui · Su/Giù (o Ctrl+K/J) = scorri · Destra = entra nel sottomenu
//   Sinistra o Backspace a campo vuoto = indietro · Esc = cancella, torna indietro, poi chiude
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../core/icons.js" as Icons
import "../../core/fuzzy.js" as Fuzzy
import "../../services"
import "../../ui"

PanelWindow {
    id: win

    readonly property bool open: Runtime.menuMode !== ""
    property var path: []              // id dei sottomenu attraversati
    property bool appsView: false      // elenco applicazioni scelto dal menu
    property var confirming: null      // voce in attesa di conferma
    property var rows: []

    screen: Compositor.focusedScreen
    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Theme.menuWidth
    implicitHeight: card.implicitHeight
    WlrLayershell.namespace: "vela-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // --- costruzione dell'elenco -------------------------------------------------
    function itemRow(item, subtitle) {
        var glyph = "";
        if (item.glyph && /^U\+[0-9A-Fa-f]+$/.test(item.glyph)) glyph = String.fromCodePoint(parseInt(item.glyph.slice(2), 16));
        return { kind: "item", label: I18n.tr(item.label), sub: subtitle || "", glyph: glyph, item: item,
                 submenu: MenuModel.isSubmenu(item), checked: MenuModel.checked(item) };
    }

    // Calcolatrice: "=" davanti, oppure un'espressione con numeri e operatori. {expr, explicit} oppure null.
    function calcQuery(q) {
        if (q.charAt(0) === "=") return { expr: q.slice(1).trim(), explicit: true };
        if (/^[0-9(.,]/.test(q) && (/[+\-*\/^%]/.test(q.slice(1)) || /\s(to|in)\s/.test(q))) return { expr: q, explicit: false };
        return null;
    }
    function calcRow(c) {
        if (Calc.expression !== c.expr) Calc.evaluate(c.expr);
        var label;
        if (!Calc.available) label = I18n.tr("Per calcolare serve qalc (libqalculate)");
        else if (c.expr === "") label = I18n.tr("Scrivi un'espressione: 2+3*4, 100 km to miles, 5 EUR to USD");
        else if (Calc.result !== "") label = "= " + Calc.result;
        else if (Calc.error !== "") label = Calc.error;
        else label = "…";
        return { kind: "calc", label: label, sub: Calc.result !== "" ? I18n.tr("Invio copia il risultato") : "", glyph: Icons.cp(0xF00EC),
                 result: Calc.result };
    }

    function rebuild() {
        var q = input.text.trim();
        var out = [];
        var appsOnly = Runtime.menuMode === "apps" || appsView;
        var calc = appsOnly ? null : calcQuery(q);
        if (calc && calc.explicit) {
            out = [calcRow(calc)];
        } else if (appsOnly) {
            out = Apps.search(q, 60);
        } else if (q === "") {
            if (path.length > 0) out.push({ kind: "back", label: I18n.tr("Indietro"), sub: "", glyph: Icons.cp(0xF004D) });
            MenuModel.level(path).forEach(function (it) { out.push(itemRow(it, "")); });
        } else {
            var hits = [];
            MenuModel.leaves().forEach(function (l) {
                var s = Fuzzy.score(q, l.label);
                var s2 = Fuzzy.score(q, l.sub + " " + l.label) * 0.7;
                if (s2 > s) s = s2;
                if (s >= 0) hits.push({ row: itemRow(l.item, l.sub), score: s + 5 });   // le voci del menu prima delle app
            });
            Apps.search(q, 40).forEach(function (r) { hits.push({ row: r, score: r.score }); });
            if (calc) hits.push({ row: calcRow(calc), score: 1000 });
            hits.sort(function (a, b) { return b.score - a.score; });
            out = hits.slice(0, 60).map(function (h) { return h.row; });
        }
        rows = out;
        list.currentIndex = out.length > 0 ? 0 : -1;
    }

    function reset() {
        path = Runtime.menuMode === "power" ? ["power"] : [];
        appsView = false;
        confirming = null;
        Calc.evaluate("");
        input.text = Runtime.menuMode === "calc" ? "=" : "";
        rebuild();
        input.forceActiveFocus();
    }

    onOpenChanged: if (open) reset()
    Connections { target: MenuModel; function onFoundChanged() { if (win.open) win.rebuild(); } }
    Connections { target: Apps; function onAllChanged() { if (win.open) win.rebuild(); } }
    Connections {
        target: Calc
        function onResultChanged() { if (win.open) win.rebuild(); }
        function onErrorChanged() { if (win.open) win.rebuild(); }
        function onAvailableChanged() { if (win.open) win.rebuild(); }
    }

    // --- azioni --------------------------------------------------------------------
    function activate(row) {
        if (!row) return;
        if (row.kind === "back") { goBack(); return; }
        if (row.kind === "calc") {
            if (row.result !== "") { Quickshell.execDetached(["wl-copy", "--", row.result]); Runtime.closeMenu(); }
            return;
        }
        if (row.kind === "app") { Runtime.closeMenu(); Apps.launch(row.entry); return; }
        var item = row.item;
        if (row.submenu) { path = path.concat([item.id]); input.text = ""; rebuild(); return; }
        if (item.action && item.action.type === "apps") { appsView = true; input.text = ""; rebuild(); return; }
        if (item.confirm === true && confirming === null) { confirming = item; return; }
        Runtime.closeMenu();
        MenuModel.run(item);
    }

    function goBack() {
        if (appsView) { appsView = false; }
        else if (path.length > 0) { path = path.slice(0, -1); }
        else return false;
        input.text = "";
        rebuild();
        return true;
    }

    function move(delta) {
        if (rows.length === 0) return;
        list.currentIndex = (list.currentIndex + delta + rows.length) % rows.length;
    }

    // --- aspetto -------------------------------------------------------------------
    Rectangle {
        id: card
        width: parent.width
        implicitHeight: header.height + sep.height + body.height + Theme.padding
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radius

        Item {
            id: header
            width: parent.width
            height: Theme.rowHeight + Theme.padding

            // Percorso corrente (es. "Alimentazione ›") davanti al campo di ricerca
            BarText {
                id: crumbs
                anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                color: Theme.accent
                visible: text !== ""
                text: {
                    var labels = [];
                    var list = MenuModel.items;
                    for (var i = 0; i < win.path.length; i++) {
                        var it = MenuModel.find(win.path.slice(0, i + 1));
                        if (it) labels.push(I18n.tr(it.label));
                    }
                    if (win.appsView || Runtime.menuMode === "apps") labels.push(I18n.tr("App"));
                    return labels.join(" › ") + (labels.length > 0 ? " ›" : "");
                }
            }
            TextInput {
                id: input
                anchors {
                    left: crumbs.visible ? crumbs.right : parent.left
                    leftMargin: crumbs.visible ? Theme.spacing : Theme.padding
                    right: parent.right; rightMargin: Theme.padding
                    verticalCenter: parent.verticalCenter
                }
                color: Theme.foreground
                selectionColor: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                clip: true
                onTextChanged: { if (win.open) { win.confirming = null; win.rebuild(); } }

                Text {
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Cerca…")
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font: input.font
                }

                Keys.onPressed: event => {
                    var ctrl = event.modifiers & Qt.ControlModifier;
                    if (event.key === Qt.Key_Escape) {
                        if (win.confirming) win.confirming = null;
                        else if (input.text !== "") input.text = "";
                        else if (!win.goBack()) Runtime.closeMenu();
                    } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J) || (ctrl && event.key === Qt.Key_N)) {
                        win.move(1);
                    } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K) || (ctrl && event.key === Qt.Key_P)) {
                        win.move(-1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        win.activate(win.confirming ? { kind: "item", item: win.confirming, submenu: false } : win.rows[list.currentIndex]);
                    } else if (event.key === Qt.Key_Right && input.cursorPosition === input.text.length) {
                        var r = win.rows[list.currentIndex];
                        if (r && r.submenu) win.activate(r);
                    } else if ((event.key === Qt.Key_Left && input.text === "") || (event.key === Qt.Key_Backspace && input.text === "")) {
                        win.goBack();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }
        }

        Rectangle { id: sep; anchors.top: header.bottom; width: parent.width; height: 1; color: Theme.border }

        Item {
            id: body
            anchors.top: sep.bottom
            width: parent.width
            height: win.confirming ? Theme.rowHeight + Theme.padding
                  : Math.max(1, Math.min(win.rows.length, Theme.menuRows)) * Theme.rowHeight + Theme.padding

            // Conferma di un'azione delicata
            BarText {
                visible: win.confirming !== null
                anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                color: Theme.warning
                text: win.confirming ? I18n.tr("%1: Invio = conferma, Esc = annulla", I18n.tr(win.confirming.label)) : ""
            }

            BarText {
                visible: win.confirming === null && win.rows.length === 0
                anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                color: Theme.muted
                text: I18n.tr("Nessun risultato")
            }

            ListView {
                id: list
                visible: win.confirming === null
                anchors { fill: parent; topMargin: Theme.padding / 2; bottomMargin: Theme.padding / 2 }
                model: win.rows
                clip: true
                currentIndex: -1
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: Theme.rowHeight
                    color: ListView.isCurrentItem ? Theme.border : "transparent"

                    Item {
                        id: iconBox
                        anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        width: Theme.iconSize + 6
                        height: Theme.iconSize + 6

                        Image {
                            anchors.fill: parent
                            visible: rowItem.modelData.kind === "app" && source != ""
                            source: rowItem.modelData.kind === "app" ? Apps.iconSource(rowItem.modelData.icon) : ""
                            sourceSize: Qt.size(Theme.iconSize * 2, Theme.iconSize * 2)
                            asynchronous: true
                        }
                        BarIcon {
                            anchors.centerIn: parent
                            visible: rowItem.modelData.kind !== "app"
                            text: rowItem.modelData.glyph || ""
                            color: Theme.muted
                        }
                    }

                    BarText {
                        id: label
                        anchors { left: iconBox.right; leftMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        text: (rowItem.modelData.checked === true ? "✓ " : rowItem.modelData.checked === false ? "○ " : "") + rowItem.modelData.label
                    }
                    BarText {
                        anchors {
                            left: label.right; leftMargin: Theme.spacing
                            right: arrow.left; rightMargin: Theme.spacing
                            verticalCenter: parent.verticalCenter
                        }
                        text: rowItem.modelData.sub || ""
                        color: Theme.dim
                        elide: Text.ElideRight
                    }
                    BarText {
                        id: arrow
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        text: rowItem.modelData.submenu ? "›" : ""
                        color: Theme.muted
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = rowItem.index
                        onClicked: win.activate(rowItem.modelData)
                    }
                }
            }
        }
    }
}
