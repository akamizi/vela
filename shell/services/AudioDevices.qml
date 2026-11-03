// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Uscite e ingressi audio per il pannello (PipeWire): volume per dispositivo, muto, predefinito.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core/audioapps.js" as Apps

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

    // Applicazioni (D-067): flussi di riproduzione (`Stream/Output/Audio`) o di registrazione (`Stream/Input/Audio`), raggruppati per
    // programma. Il tipo si legge da media.class, non da isSink, che per i flussi non è affidabile.
    function streams(mediaClass) {
        var vals = Pipewire.nodes.values, out = [];
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i], p = n.properties || {};
            if (!n.isStream || n.audio === null || p["media.class"] !== mediaClass) continue;
            out.push({ id: n.id, binary: p["application.process.binary"] || "", appName: p["application.name"] || "",
                       nodeName: p["node.name"] || n.name || "", volumes: n.audio.volumes, muted: n.audio.muted });
        }
        return Apps.group(out);
    }
    readonly property var playbackApps: streams("Stream/Output/Audio")
    readonly property var recordingApps: streams("Stream/Input/Audio")

    function streamNodes(ids) {
        return Pipewire.nodes.values.filter(function (n) { return ids.indexOf(n.id) >= 0 && n.audio !== null; });
    }
    // Massimo 100 %: un valore più alto messo da altri si mostra a fondo corsa e non si tocca finché non si muove il cursore.
    function setAppVolume(g, v) {
        streamNodes(g.ids).forEach(function (n) { n.audio.volumes = Apps.scaled(n.audio.volumes, v, 1); });
    }
    function changeAppVolume(g, delta) { setAppVolume(g, Math.min(1, g.volume) + delta); }
    function toggleAppMute(g) {
        var m = !g.muted;
        streamNodes(g.ids).forEach(function (n) { n.audio.muted = m; });
    }

    // Senza tracker i nodi non espongono volume, muto e proprietà.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    function setVolume(e, v) { e.node.audio.volume = Math.max(0, Math.min(1.5, v)); }
    function changeVolume(e, delta) { setVolume(e, e.node.audio.volume + delta); }
    function toggleMute(e) { e.node.audio.muted = !e.node.audio.muted; }
    function makeDefault(e) {
        if (e.node.isSink) Pipewire.preferredDefaultAudioSink = e.node;
        else Pipewire.preferredDefaultAudioSource = e.node;
    }
}
