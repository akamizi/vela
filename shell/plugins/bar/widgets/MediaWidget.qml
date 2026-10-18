// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Brano in riproduzione: clic = play/pausa, rotellina = precedente/successivo.
BarItem {
    visible: Media.available
    tooltip: Media.label
    onClicked: button => { if (button === Qt.LeftButton && Media.player.canTogglePlaying) Media.player.togglePlaying(); }
    onScrolled: direction => {
        if (direction > 0 && Media.player.canGoPrevious) Media.player.previous();
        else if (direction < 0 && Media.player.canGoNext) Media.player.next();
    }
    BarText { text: Media.playing ? Icons.play : Icons.pause; color: Theme.muted }
    BarText {
        text: Media.label
        font.italic: !Media.playing
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Config.shell.bar.media.maxWidth)
    }
}
