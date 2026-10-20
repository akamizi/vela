// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello del calendario (D-023, D-034): mese con numeri di settimana, si apre dal clic sull'orologio.
// ←/→ = giorno · ↑/↓ = settimana · PagSu/PagGiù = mese · T o Home = oggi · Esc = chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

PanelHost {
    id: panel
    name: "calendar"
    cardWidth: 372

    readonly property var loc: Config.shell.bar.clock.locale ? Qt.locale(Config.shell.bar.clock.locale) : Qt.locale()
    readonly property int footerHeight: 28
    readonly property int cell: 44
    readonly property int weekCol: 32
    readonly property int headerRow: 28

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date

    property date cursor: new Date()                 // giorno scelto
    readonly property int viewYear: cursor.getFullYear()
    readonly property int viewMonth: cursor.getMonth()

    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    // Sposta il cursore di n giorni (il mese in vista segue).
    function addDays(n) { cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + n); }
    // Sposta di n mesi, tenendo il giorno se esiste (il 31 diventa l'ultimo del mese più corto).
    function addMonths(n) {
        var y = cursor.getFullYear(), m = cursor.getMonth() + n, d = cursor.getDate();
        var last = new Date(y, m + 1, 0).getDate();
        cursor = new Date(y, m, Math.min(d, last));
    }
    function goToday() { cursor = new Date(); }

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        var day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    // Primo giorno della settimana secondo la lingua (Qt: 1 = lunedì … 7 = domenica).
    readonly property int firstDay: loc.firstDayOfWeek
    readonly property var weekdays: {
        var out = [];
        for (var k = 0; k < 7; k++) {
            var d = new Date(2024, 0, 1 + ((firstDay - 1 + k) % 7));      // il 1 gennaio 2024 era un lunedì
            out.push(d.toLocaleDateString(loc, "ddd").slice(0, 2));
        }
        return out;
    }
    // 6 settimane da 7 giorni che contengono il mese in vista.
    readonly property var cells: {
        var y = viewYear, m = viewMonth;
        var offset = ((new Date(y, m, 1).getDay() + 6) % 7 - (firstDay - 1) + 7) % 7;
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(y, m, 1 - offset + i);
            out.push({ date: d, day: d.getDate(), inMonth: d.getMonth() === m, week: i % 7 === 0 ? isoWeek(new Date(y, m, 1 - offset + i + 3)) : 0 });
        }
        return out;
    }

    onOpenChanged: if (open) { goToday(); keys.forceActiveFocus(); }

    contentHeight: hero.implicitHeight + 1 + headerRow + 6 * cell + Theme.padding + footerHeight

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            var k = event.key, ctrl = event.modifiers & Qt.ControlModifier;
            if (k === Qt.Key_Escape) Runtime.closePanel();
            else if (k === Qt.Key_Left || (!ctrl && k === Qt.Key_H)) panel.addDays(-1);
            else if (k === Qt.Key_Right || (!ctrl && k === Qt.Key_L)) panel.addDays(1);
            else if (k === Qt.Key_Up || (!ctrl && k === Qt.Key_K)) panel.addDays(-7);
            else if (k === Qt.Key_Down || (!ctrl && k === Qt.Key_J)) panel.addDays(7);
            else if (k === Qt.Key_PageUp) panel.addMonths(-1);
            else if (k === Qt.Key_PageDown) panel.addMonths(1);
            else if (k === Qt.Key_Home || (!ctrl && k === Qt.Key_T)) panel.goToday();
            else return;
            event.accepted = true;
        }

        PanelHero {
            id: hero
            icon: Icons.calendar
            iconColor: Theme.accent
            title: panel.cursor.toLocaleDateString(panel.loc, "MMMM yyyy")
            meta: panel.sameDay(panel.cursor, panel.now) ? I18n.tr("oggi") : panel.cursor.toLocaleDateString(panel.loc, "dddd d")
            detail: I18n.tr("settimana %1", panel.isoWeek(panel.cursor))
            trailing: Component {
                Row {
                    spacing: 2
                    Repeater {
                        model: [{ glyph: Icons.chevronLeft, step: -1 }, { glyph: Icons.chevronRight, step: 1 }]
                        delegate: Item {
                            required property var modelData
                            width: Theme.iconSize + 12
                            height: Theme.iconSize + 12
                            Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.stateHover; visible: arrowMouse.containsMouse }
                            BarIcon { anchors.centerIn: parent; text: modelData.glyph; color: Theme.muted }
                            MouseArea { id: arrowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.addMonths(modelData.step) }
                        }
                    }
                }
            }
        }
        PanelSeparator { id: sep; anchors.top: hero.bottom }

        Item {
            id: grid
            anchors { top: sep.bottom; horizontalCenter: parent.horizontalCenter }
            width: panel.weekCol + 7 * panel.cell
            height: panel.headerRow + 6 * panel.cell + Theme.padding / 2

            Row {
                y: 4
                x: panel.weekCol
                Repeater {
                    model: panel.weekdays
                    delegate: BarText {
                        required property string modelData
                        width: panel.cell
                        height: panel.headerRow
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: Theme.dim
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Repeater {
                model: panel.cells
                delegate: Item {
                    id: day
                    required property var modelData
                    required property int index
                    readonly property bool isToday: panel.sameDay(modelData.date, panel.now)
                    readonly property bool isCursor: panel.sameDay(modelData.date, panel.cursor)
                    x: panel.weekCol + (index % 7) * panel.cell
                    y: panel.headerRow + Math.floor(index / 7) * panel.cell
                    width: panel.cell
                    height: panel.cell

                    BarText {
                        visible: modelData.week > 0
                        x: -panel.weekCol
                        width: panel.weekCol - 6
                        height: parent.height
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.week
                        color: Theme.dim
                        font.pixelSize: Theme.fontSize - 3
                    }
                    Rectangle {
                        anchors { fill: parent; margins: 3 }
                        radius: Theme.radius
                        color: day.isToday ? Qt.alpha(Theme.accent, 0.25) : dayMouse.containsMouse ? Theme.stateHover : "transparent"
                        border.width: day.isCursor ? 1 : 0
                        border.color: Theme.accent
                    }
                    BarText {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: day.isToday ? Theme.accent : modelData.inMonth ? Theme.foreground : Theme.dim
                        font.bold: day.isToday
                    }
                    MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.cursor = modelData.date }
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
                text: I18n.tr("Frecce giorno · PagSu/PagGiù mese · T oggi")
            }
        }
    }
}
