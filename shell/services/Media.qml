// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Player multimediale da mostrare (MPRIS): quello in riproduzione, altrimenti il primo.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var player: {
        var ps = Mpris.players.values;
        var first = null;
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying) return ps[i];
            if (!first) first = ps[i];
        }
        return first;
    }
    readonly property bool available: player !== null
    readonly property bool playing: available && player.isPlaying
    readonly property string title: available ? player.trackTitle : ""
    readonly property string artist: available ? player.trackArtist : ""
    readonly property string label: artist !== "" && title !== "" ? artist + " - " + title : (title !== "" ? title : (available ? player.identity : ""))
}
