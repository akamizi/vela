// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Icona Nerd Font della barra.
import QtQuick
import "../core"

Text {
    color: Theme.foreground
    font.family: Theme.iconFamily
    // Dentro la barra (Bar.qml marca il suo contenitore con isBarZone) si usa la dimensione della barra.
    readonly property bool inBar: {
        for (var p = parent; p; p = p.parent)
            if (p.isBarZone === true) return true;
        return false;
    }
    font.pixelSize: inBar ? Theme.barIconSize : Theme.iconSize
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
