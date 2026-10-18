// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Titolo della finestra attiva (testo esterno: solo testo semplice).
BarItem {
    clickable: false
    visible: Compositor.activeTitle !== ""
    BarText {
        text: Compositor.activeTitle
        color: Theme.muted
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Config.shell.bar.windowTitle.maxWidth)
    }
}
