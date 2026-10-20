// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Aggiornamenti disponibili (D-037): compare solo se ce ne sono. Clic = avvia l'aggiornamento in un terminale, clic destro = ricontrolla.
BarItem {
    visible: Updates.enabled && Updates.count > 0
    tooltip: {
        var n = Updates.count, shown = Updates.names.slice(0, 8).join(", ") + (n > 8 ? "…" : "");
        return (n === 1 ? I18n.tr("%1 aggiornamento", n) : I18n.tr("%1 aggiornamenti", n)) + ": " + shown;
    }
    onClicked: button => {
        if (button === Qt.LeftButton) Updates.upgrade();
        else if (button === Qt.RightButton) Updates.refresh();
    }
    BarIcon { text: Icons.updates; color: Updates.running ? Theme.muted : Theme.accent }
    BarText { text: Updates.count; color: Updates.running ? Theme.muted : Theme.accent }
}
