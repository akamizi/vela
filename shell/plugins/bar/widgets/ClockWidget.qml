// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Orologio: clic = formato alternativo; tooltip = calendario del mese.
BarItem {
    id: root
    property bool alt: false
    readonly property var loc: Config.shell.bar.clock.locale ? Qt.locale(Config.shell.bar.clock.locale) : Qt.locale()
    readonly property var cfg: Config.shell.bar.clock

    tooltipMono: true
    tooltip: calendar(clock.date)
    onClicked: button => { if (button === Qt.LeftButton) alt = !alt; }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Calendario del mese in testo monospaziato, con il giorno corrente tra parentesi.
    function calendar(date) {
        var y = date.getFullYear(), m = date.getMonth(), today = date.getDate();
        var first = loc.firstDayOfWeek;                       // 1 = lunedì ... 7 = domenica (Qt)
        var lines = [date.toLocaleDateString(loc, "MMMM yyyy")];
        var head = "";
        for (var k = 0; k < 7; k++) {
            var d = new Date(2024, 0, 1 + ((first - 1 + k) % 7));   // 1 gen 2024 era un lunedì
            head += (" " + d.toLocaleDateString(loc, "ddd").slice(0, 2) + " ");
        }
        lines.push(head);
        var offset = (new Date(y, m, 1).getDay() + 6) % 7;        // lunedì = 0
        offset = (offset - (first - 1) + 7) % 7;
        var days = new Date(y, m + 1, 0).getDate();
        var row = "    ".repeat(offset);
        for (var n = 1; n <= days; n++) {
            var cell = n === today ? "[" + (n < 10 ? " " : "") + n + "]" : " " + (n < 10 ? " " : "") + n + " ";
            row += cell;
            if ((offset + n) % 7 === 0) { lines.push(row); row = ""; }
        }
        if (row !== "") lines.push(row);
        return lines.join("\n");
    }

    BarText {
        text: clock.date.toLocaleString(root.loc, root.alt ? root.cfg.formatAlt : root.cfg.format)
    }
}
