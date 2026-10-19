// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Web radio: visibile mentre una stazione suona (o dà errore). Clic = pannello, clic destro = ferma.
BarItem {
    visible: Radio.state !== "stopped"
    tooltip: Radio.state === "error" ? Radio.name + ": " + Radio.error : Radio.name + (Radio.state === "starting" ? " (" + I18n.tr("connessione…") + ")" : "")
    onClicked: button => {
        if (button === Qt.RightButton) Radio.stop();
        else if (MenuModel.availablePanels.indexOf("radio") >= 0) Runtime.togglePanel("radio");
    }
    BarIcon { text: Icons.radio; color: Radio.state === "error" ? Theme.warning : Theme.accent }
    BarText {
        text: Radio.name
        font.italic: Radio.state !== "playing"
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Config.shell.bar.radio.maxWidth)
    }
}
