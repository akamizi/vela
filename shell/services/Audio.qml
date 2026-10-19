// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Volume dell'uscita audio predefinita (PipeWire).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0        // 1.0 = 100%
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property string deviceName: sink ? sink.description : ""

    // Microfono predefinito (tasto di muto del microfono)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micAvailable: source !== null && source.audio !== null
    readonly property bool micMuted: micAvailable ? source.audio.muted : false

    PwObjectTracker { objects: [root.sink, root.source] }

    function toggleMicMute() {
        if (micAvailable) source.audio.muted = !source.audio.muted;
    }

    function change(delta, maxVolume) {
        if (!available) return;
        sink.audio.volume = Math.max(0, Math.min(maxVolume, volume + delta));
    }

    function toggleMute() {
        if (available) sink.audio.muted = !sink.audio.muted;
    }
}
