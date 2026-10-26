// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Web radio: un solo flusso alla volta, riprodotto dal Player condiviso (mpv di default).
// Le stazioni stanno in configurazione (radio.stations). Qui resta l'elenco e la vista sullo stato del Player.
pragma Singleton
import QtQuick
import Quickshell
import "../core"

Singleton {
    id: root

    readonly property var stations: (Config.shell.radio.stations || []).filter(function (s) {
        return s && typeof s.name === "string" && s.name !== "" && validUrl(s.url);
    })
    // Lo stato è quello del Player solo se ciò che suona è una radio.
    readonly property bool mine: Player.kind === "radio"
    readonly property string state: mine ? Player.state : "stopped"
    readonly property string name: mine ? Player.name : ""
    readonly property string url: mine ? Player.key : ""
    readonly property string error: mine ? Player.error : ""
    readonly property bool playing: mine && Player.playing

    function validUrl(u) { return typeof u === "string" && /^(https?|rtmps?|rtsp|mms):\/\/\S+$/.test(u); }

    function play(station) {
        if (!station || !validUrl(station.url)) return;
        // `--` impedisce che l'indirizzo sia preso per un'opzione.
        Player.play("radio", station.name, station.url, ["--", station.url]);
    }
    function stop() { if (mine) Player.stop(); }
    function toggle(station) { if (playing && url === station.url) stop(); else play(station); }
}
