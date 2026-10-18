// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Indicatore di registrazione schermo; clic = ferma (se configurato).
BarItem {
    visible: Toggles.recording
    tooltip: "Registrazione in corso"
    onClicked: Toggles.stopRecording()
    BarIcon { text: Icons.recording; color: Theme.error }
    BarText { text: "REC"; color: Theme.error; font.bold: true }
}
