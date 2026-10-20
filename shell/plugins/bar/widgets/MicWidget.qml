// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Microfono (D-036): clic = muto, clic centrale = pannello audio, rotellina = volume in ingresso. Spento di default:
// si aggiunge da Impostazioni › Barra. Nascosto se non c'è un microfono.
BarItem {
    visible: Audio.micAvailable
    tooltip: Audio.micName + " · " + (Audio.micMuted ? I18n.tr("muto") : Math.round(Audio.micVolume * 100) + "%")
    onScrolled: direction => Audio.changeMic(direction * Config.shell.audio.step, Config.shell.audio.maxVolume)
    onClicked: button => {
        if (button === Qt.LeftButton) Audio.toggleMicMute();
        else if (button === Qt.MiddleButton && MenuModel.availablePanels.indexOf("audio") >= 0) Runtime.togglePanel("audio", mapToGlobal(width / 2, 0).x);
    }
    BarIcon {
        text: Audio.micMuted ? Icons.micOff : Icons.mic
        color: Audio.micMuted ? Theme.muted : Theme.foreground
    }
}
