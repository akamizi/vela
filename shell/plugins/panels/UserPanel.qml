// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello utente: foto e nome, riga di stato (batteria, rete, energia) e le azioni di sessione.
// ↑/↓ scelgono · Invio = attiva · lettera della riga = scelta diretta · Esc = annulla la conferma o chiude.
// Esci, Riavvia e Spegni chiedono una seconda conferma (stessa lettera o Invio).
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "user"
    cardWidth: Math.max(Theme.panelWidth, 380)

    readonly property int footerHeight: 28
    readonly property int avatar: 64
    property int cursor: 0
    property int confirming: -1

    // key = lettera di scelta diretta (maiuscola), confirm = chiede conferma
    readonly property var rows: [
        { key: "I", label: I18n.tr("Impostazioni"), icon: Icons.cp(0xF0493), run: "settings" },
        { key: "L", label: I18n.tr("Blocca"), icon: Icons.lock, run: "lock" },
        { key: "S", label: I18n.tr("Sospendi"), icon: Icons.cp(0xF0904), run: "suspend" },
        { key: "E", label: I18n.tr("Esci dalla sessione"), icon: Icons.cp(0xF0343), run: "logout", confirm: true },
        { key: "R", label: I18n.tr("Riavvia"), icon: Icons.cp(0xF0709), run: "reboot", confirm: true },
        { key: "P", label: I18n.tr("Spegni"), icon: Icons.power, run: "poweroff", confirm: true }
    ]

    readonly property string statusText: {
        var parts = [];
        if (Power.hasBattery) {
            var b = Math.round(Power.percent) + "%";
            if (Power.charging) b += " · " + I18n.tr("in carica");
            else if (Power.plugged) b += " · " + I18n.tr("collegata");
            parts.push(b);
        }
        var n = NetworkStatus.summary;
        parts.push(n.kind === "none" ? I18n.tr("Rete assente") : n.name);
        parts.push(Power.profileLabel);
        return parts.join("  ·  ");
    }

    function move(delta) { confirming = -1; cursor = (cursor + delta + rows.length) % rows.length; }

    function run(r) {
        Runtime.closePanel();
        if (r.run === "settings") Runtime.openPanel("settings");
        else if (r.run === "lock") Idle.lock();
        else if (r.run === "suspend") Quickshell.execDetached(["loginctl", "suspend"]);
        else Session.request(r.run);
    }

    function choose(i) {
        if (i < 0 || i >= rows.length) return;
        var r = rows[i];
        cursor = i;
        if (r.confirm === true && confirming !== i) { confirming = i; return; }
        run(r);
    }

    onOpenChanged: {
        if (open) { cursor = 0; confirming = -1; UserInfo.refresh(); keys.forceActiveFocus(); }
    }

    contentHeight: head.height + 1 + rows.length * (Theme.rowHeight + 6) + Theme.spacing + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var ctrl = event.modifiers & Qt.ControlModifier;
            if (event.key === Qt.Key_Escape) {
                if (panel.confirming >= 0) panel.confirming = -1; else Runtime.closePanel();
            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                panel.move(1);
            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                panel.move(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                panel.choose(panel.cursor);
            } else if (!ctrl && event.text !== "") {
                var k = event.text.toUpperCase();
                for (var i = 0; i < panel.rows.length; i++)
                    if (panel.rows[i].key === k) { panel.choose(i); event.accepted = true; return; }
                return;
            } else {
                return;
            }
            event.accepted = true;
        }

        Item {
            id: head
            width: parent.width
            height: panel.avatar + Theme.padding * 2 + statusLine.implicitHeight + Theme.spacing

            ClippingRectangle {
                id: photo
                anchors { left: parent.left; leftMargin: Theme.padding + 2; top: parent.top; topMargin: Theme.padding }
                width: panel.avatar; height: panel.avatar
                radius: width / 2
                color: Theme.stateSelected
                border.width: 1
                border.color: Theme.softBorder
                Image {
                    anchors.fill: parent
                    visible: UserInfo.hasFace && status === Image.Ready
                    source: UserInfo.hasFace ? "file://" + UserInfo.facePath : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(panel.avatar * 2, panel.avatar * 2)
                    asynchronous: true
                }
                BarText {
                    anchors.centerIn: parent
                    visible: !UserInfo.hasFace
                    text: UserInfo.initial
                    font.bold: true
                    font.pixelSize: panel.avatar / 2
                }
            }
            Column {
                anchors { left: photo.right; leftMargin: Theme.padding; right: parent.right; rightMargin: Theme.padding; verticalCenter: photo.verticalCenter }
                spacing: 2
                BarText {
                    width: parent.width
                    text: UserInfo.displayName
                    font.bold: true
                    font.pixelSize: Theme.fontSize + 3
                    elide: Text.ElideRight
                }
                BarText {
                    width: parent.width
                    text: UserInfo.user + "@" + UserInfo.host
                    color: Theme.muted
                    elide: Text.ElideRight
                }
                BarText {
                    width: parent.width
                    text: I18n.tr("In funzione da %1", UserInfo.uptimeText)
                    color: Theme.dim
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                }
            }
            BarText {
                id: statusLine
                anchors { left: parent.left; right: parent.right; leftMargin: Theme.padding + 2; rightMargin: Theme.padding; top: photo.bottom; topMargin: Theme.spacing }
                text: panel.statusText
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 1
                elide: Text.ElideRight
            }
        }
        PanelSeparator { id: sep; anchors.top: head.bottom }

        Column {
            anchors { top: sep.bottom; left: parent.left; right: parent.right; topMargin: Theme.spacing / 2 }
            Repeater {
                model: panel.rows
                delegate: PanelRow {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool asking: panel.confirming === index
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.spacing; rightMargin: Theme.spacing }
                    height: Theme.rowHeight + 4
                    hasCursor: panel.cursor === index
                    icon: modelData.icon
                    iconColor: asking ? Theme.error : modelData.confirm === true ? Theme.muted : Theme.accent
                    title: asking ? I18n.tr("%1: premi di nuovo per confermare", modelData.label) : modelData.label
                    titleColor: asking ? Theme.error : Theme.foreground
                    trailingText: modelData.key
                    onMoved: panel.cursor = index
                    onClicked: panel.choose(index)
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
                text: I18n.tr("Invio attiva · lettera = scelta diretta · Esc chiude")
            }
        }
    }
}
