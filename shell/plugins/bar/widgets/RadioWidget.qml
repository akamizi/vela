// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Audio in corso (radio, musica, Subsonic): visibile mentre qualcosa suona (o dà errore). Clic = pannello, clic destro = ferma.
BarItem {
    visible: Player.state !== "stopped"
    tooltip: Player.state === "error" ? Player.name + ": " + Player.error : Player.name + (Player.state === "starting" ? " (" + I18n.tr("connessione…") + ")" : "")
    onClicked: button => {
        if (button === Qt.RightButton) Player.stop();
        else if (MenuModel.availablePanels.indexOf(Player.kind) >= 0) Runtime.togglePanel(Player.kind);
    }
    BarIcon { text: Player.kind === "radio" ? Icons.radio : Icons.music; color: Player.state === "error" ? Theme.warning : Theme.accent }
    BarText {
        text: Player.name
        font.italic: Player.state !== "playing"
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Config.shell.bar.radio.maxWidth)
    }
}
