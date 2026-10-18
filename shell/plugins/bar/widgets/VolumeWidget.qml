// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Volume: rotellina = ±2%, clic destro = muto. Clic = pannello.
BarItem {
    visible: Audio.available
    tooltip: Math.round(Audio.volume * 100) + "% · " + Audio.deviceName
    onScrolled: direction => Audio.change(direction * Config.shell.audio.step, Config.shell.audio.maxVolume)
    onClicked: button => {
        if (button === Qt.RightButton) Audio.toggleMute();
        else if (MenuModel.availablePanels.indexOf("audio") >= 0) Runtime.togglePanel("audio", mapToGlobal(width / 2, 0).x);
    }
    BarIcon {
        text: Audio.muted ? Icons.volumeMuted : Icons.pick(Icons.volume, Audio.volume)
        color: Audio.muted ? Theme.muted : Theme.foreground
    }
}
