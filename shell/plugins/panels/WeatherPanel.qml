// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello del meteo (D-023, D-035): condizioni attuali, prossime 24 ore e prossimi giorni, dai dati di yr.no.
// Si apre dal clic sull'elemento della barra. R = aggiorna · Esc = chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "weather"
    cardWidth: 480

    readonly property var loc: Config.shell.bar.clock.locale ? Qt.locale(Config.shell.bar.clock.locale) : Qt.locale()
    readonly property int footerHeight: 28
    readonly property int sectionHeight: 28
    readonly property int statsHeight: 52
    readonly property int hoursHeight: 96
    readonly property int staleHeight: Weather.stale ? 26 : 0
    readonly property var cur: Weather.current

    function deg(v) { return Math.round(v) + "°"; }
    function mm(v) { return v >= 0.1 ? (Math.round(v * 10) / 10) + " mm" : ""; }

    onOpenChanged: if (open) keys.forceActiveFocus()

    contentHeight: hero.implicitHeight + 1 + staleHeight + statsHeight + sectionHeight + hoursHeight + sectionHeight
                   + Weather.days.length * Theme.rowHeight + Theme.padding + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) Runtime.closePanel();
            else if (event.key === Qt.Key_R && !(event.modifiers & Qt.ControlModifier)) Weather.refresh();
            else return;
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: panel.cur ? panel.cur.icon : Icons.weather.cloudy
            iconColor: Theme.accent
            title: Config.shell.weather.placeName || I18n.tr("Meteo")
            meta: panel.cur ? panel.cur.label : I18n.tr("dati non disponibili")
            detail: panel.cur ? panel.deg(panel.cur.temp) + Weather.unitLabel.slice(1) : ""
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        BarText {
            id: stale
            visible: Weather.stale
            anchors { top: sep.bottom; left: parent.left; right: parent.right; leftMargin: Theme.padding; rightMargin: Theme.padding }
            height: panel.staleHeight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: Theme.warning
            font.pixelSize: Theme.fontSize - 2
            text: "⚠ " + I18n.tr("dati dalla cache") + (Weather.ageMinutes >= 0 ? " (" + I18n.tr("%1 min fa", Weather.ageMinutes) + ")" : "") + " — " + I18n.tr("rete non raggiungibile")
        }

        // Vento, umidità, pressione
        Row {
            id: stats
            anchors { top: stale.visible ? stale.bottom : sep.bottom; left: parent.left; right: parent.right }
            height: panel.statsHeight
            Repeater {
                model: panel.cur ? [
                    { label: I18n.tr("Vento"), value: Math.round(panel.cur.wind) + " " + Weather.windUnit },
                    { label: I18n.tr("Umidità"), value: Math.round(panel.cur.humidity) + "%" },
                    { label: I18n.tr("Pressione"), value: Math.round(panel.cur.pressure) + " hPa" }
                ] : []
                delegate: Column {
                    required property var modelData
                    width: stats.width / 3
                    height: stats.height
                    spacing: 2
                    topPadding: 8
                    BarText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.value; font.bold: true }
                    BarText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: Theme.dim; font.pixelSize: Theme.fontSize - 3 }
                }
            }
        }

        PanelSectionHeader { id: hoursHead; anchors.top: stats.bottom; text: I18n.tr("Prossime ore") }
        Row {
            id: hoursRow
            anchors { top: hoursHead.bottom; left: parent.left; right: parent.right; leftMargin: Theme.padding / 2; rightMargin: Theme.padding / 2 }
            height: panel.hoursHeight
            Repeater {
                model: Weather.hours
                delegate: Column {
                    required property var modelData
                    width: hoursRow.width / Math.max(1, Weather.hours.length)
                    spacing: 3
                    topPadding: 4
                    BarText { width: parent.width; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; font.pixelSize: Theme.fontSize - 2
                              text: new Date(modelData.time).toLocaleTimeString(panel.loc, "HH") }
                    BarIcon { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: Theme.accent }
                    BarText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: panel.deg(modelData.temp) }
                    BarText { width: parent.width; horizontalAlignment: Text.AlignHCenter; color: Theme.dim; font.pixelSize: Theme.fontSize - 3; text: panel.mm(modelData.precip) }
                }
            }
        }

        PanelSectionHeader { id: daysHead; anchors.top: hoursRow.bottom; text: I18n.tr("Prossimi giorni") }
        Column {
            anchors { top: daysHead.bottom; left: parent.left; right: parent.right }
            Repeater {
                model: Weather.days
                delegate: Item {
                    id: dayRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: Theme.rowHeight
                    BarText {
                        id: dayName
                        anchors { left: parent.left; leftMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        width: 70
                        text: dayRow.index === 0 ? I18n.tr("Oggi") : dayRow.modelData.date.toLocaleDateString(panel.loc, "ddd d")
                        font.bold: dayRow.index === 0
                    }
                    BarIcon { id: dayIcon; anchors { left: dayName.right; verticalCenter: parent.verticalCenter } text: dayRow.modelData.icon; color: Theme.accent }
                    BarText {
                        anchors { left: dayIcon.right; leftMargin: Theme.spacing; right: precip.left; rightMargin: Theme.spacing; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        color: Theme.muted
                        text: dayRow.modelData.label
                    }
                    BarText {
                        id: precip
                        anchors { right: range.left; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        color: Theme.dim
                        font.pixelSize: Theme.fontSize - 2
                        text: panel.mm(dayRow.modelData.precip)
                    }
                    BarText {
                        id: range
                        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: parent.verticalCenter }
                        width: 78
                        horizontalAlignment: Text.AlignRight
                        text: panel.deg(dayRow.modelData.max) + " / " + panel.deg(dayRow.modelData.min)
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
                text: I18n.tr("R aggiorna · Esc chiude") + "  ·  yr.no"
            }
        }
    }
}
