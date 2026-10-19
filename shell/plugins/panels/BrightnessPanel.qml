// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello della luminosità dello schermo (D-023, D-029): cursore grande, si apre dal clic sull'icona della barra.
// ←/→ o ↑/↓ = passo · PagSu/PagGiù = ±20% · 1…9 e 0 = 10…100% · Home/Fine = minimo/massimo · Esc = chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "brightness"
    cardWidth: Math.max(Theme.panelWidth, 380)

    readonly property int footerHeight: 28
    readonly property int sliderHeight: 64
    readonly property real step: Config.shell.brightness.step / 100

    function nudge(delta) { Brightness.set(Math.max(0.01, Math.min(1, Brightness.level + delta))); }

    onOpenChanged: if (open) { Brightness.read(); keys.forceActiveFocus(); }

    contentHeight: hero.implicitHeight + 1 + sliderHeight + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var k = event.key;
            if (k === Qt.Key_Escape) {
                Runtime.closePanel();
            } else if (k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_L || k === Qt.Key_K) {
                panel.nudge(panel.step);
            } else if (k === Qt.Key_Left || k === Qt.Key_Down || k === Qt.Key_H || k === Qt.Key_J) {
                panel.nudge(-panel.step);
            } else if (k === Qt.Key_PageUp) {
                panel.nudge(0.2);
            } else if (k === Qt.Key_PageDown) {
                panel.nudge(-0.2);
            } else if (k === Qt.Key_Home) {
                Brightness.set(0.01);
            } else if (k === Qt.Key_End) {
                Brightness.set(1);
            } else if (k >= Qt.Key_1 && k <= Qt.Key_9 && !(event.modifiers & Qt.ControlModifier)) {
                Brightness.set((k - Qt.Key_0) / 10);
            } else if (k === Qt.Key_0 && !(event.modifiers & Qt.ControlModifier)) {
                Brightness.set(1);
            } else {
                return;
            }
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: Icons.pick(Icons.brightness, Brightness.level)
            iconColor: Theme.accent
            title: I18n.tr("Luminosità")
            meta: Brightness.available ? Brightness.device : I18n.tr("nessuno schermo regolabile")
            detail: Brightness.available ? Math.round(Brightness.level * 100) + "%" : ""
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        Item {
            anchors { top: sep.bottom; left: parent.left; right: parent.right }
            height: panel.sliderHeight
            BarIcon {
                id: low
                anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: Icons.brightness[0]
                color: Theme.muted
            }
            BarIcon {
                id: high
                anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                text: Icons.brightness[2]
                color: Theme.muted
            }
            PanelSlider {
                anchors { left: low.right; right: high.left; leftMargin: Theme.padding; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                height: 28
                value: Brightness.level
                maxValue: 1
                interactive: Brightness.available
                onMoved: v => Brightness.set(v)
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
                text: I18n.tr("←/→ regola · 1-9 = 10-90% · Esc chiude")
            }
        }
    }
}
