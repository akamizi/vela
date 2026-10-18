// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Uscite e ingressi audio per il pannello (PipeWire): volume per dispositivo, muto, predefinito.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property bool available: Pipewire.ready

    // Dispositivi reali (non i flussi delle applicazioni).
    function collect(wantSink) {
        var vals = Pipewire.nodes.values, out = [];
        var def = wantSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i];
            if (n.isStream || n.isSink !== wantSink || n.audio === null) continue;
            out.push({ node: n, id: n.id, name: n.description || n.nickname || n.name,
                       volume: n.audio.volume, muted: n.audio.muted, isDefault: def !== null && def.id === n.id });
        }
        out.sort(function (a, b) { return a.name.localeCompare(b.name); });
        return out;
    }
    readonly property var sinks: collect(true)
    readonly property var sources: collect(false)

    // Senza tracker i nodi non espongono volume e muto.
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(function (n) { return !n.isStream; })
    }

    function setVolume(e, v) { e.node.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function changeVolume(e, delta) { setVolume(e, e.node.audio.volume + delta); }
    function toggleMute(e) { e.node.audio.muted = !e.node.audio.muted; }
    function makeDefault(e) {
        if (e.node.isSink) Pipewire.preferredDefaultAudioSink = e.node;
        else Pipewire.preferredDefaultAudioSource = e.node;
    }
}
