// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello del limite di carica (D-023, D-032): interruttore del limite e carica piena una tantum.
// Compare solo sui portatili compatibili (soglie regolabili o limite fisso del firmware).
// ↑/↓ scelgono · Invio o Spazio = attiva · L = limite · F = carica piena · Esc = chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "battery"
    cardWidth: Math.max(Theme.panelWidth, 400)

    readonly property int footerHeight: 28
    readonly property int rowCount: 2
    property int cursor: 0
    readonly property bool usable: BatteryLimit.helperInstalled && !BatteryLimit.busy
    readonly property bool fixedMode: BatteryLimit.mode === "fixed"

    readonly property string limitTitle: fixedMode ? I18n.tr("Limite di carica del portatile") : I18n.tr("Limita la carica all'%1%", BatteryLimit.limitEnd)
    readonly property string limitDesc: fixedMode ? I18n.tr("Limite fisso deciso dal firmware")
                                                  : I18n.tr("Si ferma all'%1%, riprende sotto il %2%", BatteryLimit.limitEnd, BatteryLimit.limitStart)
    readonly property string fullTitle: BatteryLimit.full ? I18n.tr("Annulla la carica piena") : I18n.tr("Carica al 100% una volta")
    readonly property string fullDesc: BatteryLimit.full ? I18n.tr("In corso: al termine il limite torna da solo")
                                                         : I18n.tr("Poi il limite torna da solo")
    readonly property bool fullPossible: BatteryLimit.full || BatteryLimit.wanted

    function move(delta) { cursor = (cursor + delta + rowCount) % rowCount; }
    function activate(i) {
        if (!usable) return;
        if (i === 0) BatteryLimit.toggleLimit();
        else if (fullPossible) BatteryLimit.toggleFull();
    }

    onOpenChanged: {
        if (open) { cursor = 0; BatteryLimit.refresh(); keys.forceActiveFocus(); }
    }

    readonly property int messageLines: (!BatteryLimit.helperInstalled ? 1 : 0) + (BatteryLimit.error !== "" ? 1 : 0)
    contentHeight: hero.implicitHeight + 1 + rowCount * (Theme.rowHeight + 14) + Theme.spacing
                   + messageLines * (Theme.rowHeight - 6) + footerHeight

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
                panel.activate(panel.cursor);
            } else if (!ctrl && event.key === Qt.Key_L) {
                panel.cursor = 0; panel.activate(0);
            } else if (!ctrl && event.key === Qt.Key_F) {
                panel.cursor = 1; panel.activate(1);
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: Power.plugged ? Icons.plug : Icons.pick(Power.charging ? Icons.batteryCharging : Icons.battery, Power.percent / 100)
            iconColor: Theme.accent
            title: I18n.tr("Batteria")
            meta: BatteryLimit.full ? I18n.tr("carica piena in corso") : BatteryLimit.limited ? I18n.tr("limite attivo") : I18n.tr("limite spento")
            detail: Math.round(Power.percent) + "%" + (Power.charging ? " · " + I18n.tr("in carica") : Power.onAc ? " · " + I18n.tr("collegata") : "")
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        Column {
            anchors { top: sep.bottom; left: parent.left; right: parent.right; topMargin: Theme.spacing / 2 }

            Item {
                width: parent.width
                height: Theme.rowHeight + 14
                PanelRow {
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing; topMargin: 2; bottomMargin: 2 }
                    hasCursor: panel.cursor === 0
                    icon: Icons.battery[Icons.battery.length - 1]
                    iconColor: BatteryLimit.wanted ? Theme.accent : Theme.muted
                    title: panel.limitTitle
                    trailing: Component {
                        ToggleSwitch {
                            checked: BatteryLimit.wanted
                            busy: !panel.usable
                            hasCursor: panel.cursor === 0
                            onToggled: panel.activate(0)
                        }
                    }
                    onMoved: panel.cursor = 0
                    onClicked: { panel.cursor = 0; panel.activate(0); }
                }
                BarText {
                    anchors { left: parent.left; leftMargin: Theme.spacing + Theme.padding + Theme.iconSize + Theme.spacing; bottom: parent.bottom; bottomMargin: 3 }
                    text: panel.limitDesc
                    color: Theme.dim
                    font.pixelSize: Theme.fontSize - 3
                }
            }

            Item {
                width: parent.width
                height: Theme.rowHeight + 14
                opacity: panel.fullPossible ? 1 : 0.5
                PanelRow {
                    anchors { fill: parent; leftMargin: Theme.spacing; rightMargin: Theme.spacing; topMargin: 2; bottomMargin: 2 }
                    hasCursor: panel.cursor === 1
                    selected: BatteryLimit.full
                    icon: Icons.pick(Icons.batteryCharging, 1)
                    iconColor: BatteryLimit.full ? Theme.accent : Theme.muted
                    title: panel.fullTitle
                    bold: BatteryLimit.full
                    onMoved: panel.cursor = 1
                    onClicked: { panel.cursor = 1; panel.activate(1); }
                }
                BarText {
                    anchors { left: parent.left; leftMargin: Theme.spacing + Theme.padding + Theme.iconSize + Theme.spacing; bottom: parent.bottom; bottomMargin: 3 }
                    text: panel.fullPossible ? panel.fullDesc : I18n.tr("Serve il limite attivo")
                    color: Theme.dim
                    font.pixelSize: Theme.fontSize - 3
                }
            }

            BarText {
                visible: !BatteryLimit.helperInstalled
                width: parent.width - Theme.padding * 2
                x: Theme.padding
                height: Theme.rowHeight - 6
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: Theme.warning
                text: I18n.tr("Manca l'helper di sistema: doas make install-system")
            }
            BarText {
                visible: BatteryLimit.error !== ""
                width: parent.width - Theme.padding * 2
                x: Theme.padding
                height: Theme.rowHeight - 6
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: Theme.error
                text: BatteryLimit.error
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
                text: I18n.tr("Invio attiva · L limite · F carica piena · Esc chiude")
            }
        }
    }
}
