// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Testo della barra: tema e testo semplice (mai markup).
import QtQuick
import "../core"

Text {
    color: Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
