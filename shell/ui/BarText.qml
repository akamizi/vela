// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Testo della barra: tema e testo semplice (mai markup).
import QtQuick
import "../core"

Text {
    color: Theme.foreground
    font.family: Theme.fontFamily
    // Dentro la barra (Bar.qml marca il suo contenitore con isBarZone) si usa la dimensione della barra.
    readonly property bool inBar: {
        for (var p = parent; p; p = p.parent)
            if (p.isBarZone === true) return true;
        return false;
    }
    font.pixelSize: inBar ? Theme.barFontSize : Theme.fontSize
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
