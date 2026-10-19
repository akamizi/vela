// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello del profilo energetico (D-023, D-027): i profili di power-profiles-daemon (via UPower), quello attivo in evidenza.
// Invio o clic = attiva · 1/2/3 = scelta diretta · Esc = chiude.
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "power"
    cardWidth: Math.max(Theme.panelWidth, 380)

    readonly property int footerHeight: 28
    readonly property var rows: Power.profiles
    property int cursor: 0

    function iconFor(v) { return v === PowerProfile.Performance ? Icons.performance : v === PowerProfile.PowerSaver ? Icons.powerSaver : Icons.balanced; }
    function move(delta) { if (rows.length > 0) cursor = (cursor + delta + rows.length) % rows.length; }
    function choose(i) { if (i >= 0 && i < rows.length) Power.setProfile(rows[i].value); }

    onOpenChanged: {
        if (open) {
            cursor = Math.max(0, rows.map(function (r) { return r.value; }).indexOf(Power.profile));
            keys.forceActiveFocus();
        }
    }

    contentHeight: hero.implicitHeight + 1 + rows.length * (Theme.rowHeight + 14) + Theme.spacing + footerHeight

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
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                panel.choose(panel.cursor);
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !ctrl) {
                panel.choose(event.key - Qt.Key_1);
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: panel.iconFor(Power.profile)
            iconColor: Theme.accent
            title: "Energia"
            meta: Power.profileLabel
            detail: Power.hasBattery ? Math.round(Power.percent) + "%" + (Power.charging ? " · in carica" : Power.onAc ? " · alimentatore" : "") : "alimentatore"
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        Column {
            anchors { top: sep.bottom; left: parent.left; right: parent.right; topMargin: Theme.spacing / 2 }
            Repeater {
                model: panel.rows
                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: Theme.rowHeight + 14

                    PanelRow {
                        anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing; topMargin: 2; bottomMargin: 2 }
                        height: parent.height - 4
                        hasCursor: panel.cursor === entry.index
                        selected: Power.profile === entry.modelData.value
                        icon: panel.iconFor(entry.modelData.value)
                        iconColor: selected ? Theme.accent : Theme.muted
                        title: entry.modelData.label
                        bold: selected
                        onMoved: panel.cursor = entry.index
                        onClicked: { panel.cursor = entry.index; panel.choose(entry.index); }
                    }
                    BarText {
                        anchors { left: parent.left; leftMargin: Theme.spacing + Theme.padding + Theme.iconSize + Theme.spacing; bottom: parent.bottom; bottomMargin: 3 }
                        text: entry.modelData.desc
                        color: Theme.dim
                        font.pixelSize: Theme.fontSize - 3
                    }
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
                text: "Invio attiva · 1-" + panel.rows.length + " scelta diretta · Esc chiude"
            }
        }
    }
}
