// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Interruttori e indicatori di stato: luce notturna, non disturbare, registrazione schermo.
// "Resta sveglio" non sta qui: è un inibitore di idle Wayland legato a una finestra (widget Awake).
// Le sorgenti esterne si interrogano a intervalli (non emettono eventi); ogni comando è un array di argomenti.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool awake: false          // stato interno, nessun processo esterno
    property bool night: false
    property bool dnd: false
    property bool recording: false
    property bool dndAvailable: false

    readonly property var recordingCommand: Config.shell.toggles.recordingCommand

    function setAwake(on) { awake = on; }

    // --- luce notturna (gammastep) ---
    Process {
        id: nightCheck
        command: ["pgrep", "-x", "gammastep"]
        onExited: code => root.night = (code === 0)
    }

    function toggleNight() {
        if (night) Quickshell.execDetached(["pkill", "-x", "gammastep"]);
        else Quickshell.execDetached(["gammastep", "-O", String(Config.shell.toggles.nightTemperature)]);
        night = !night;
        refreshSoon.restart();
    }

    // --- non disturbare (provvisorio: dunst, finché le notifiche non sono integrate, D-006) ---
    Process {
        id: dndCheck
        command: ["dunstctl", "is-paused"]
        stdout: StdioCollector {
            onStreamFinished: { root.dnd = text.trim() === "true"; root.dndAvailable = true; }
        }
    }

    function toggleDnd() {
        if (!dndAvailable) return;
        Quickshell.execDetached(["dunstctl", "set-paused", "toggle"]);
        dnd = !dnd;
        refreshSoon.restart();
    }

    // --- registrazione schermo: comando esterno facoltativo, esce con 0 se si sta registrando ---
    Process {
        id: recCheck
        command: root.recordingCommand ? root.recordingCommand : ["true"]
        onExited: code => root.recording = (root.recordingCommand !== null && code === 0)
    }

    function stopRecording() {
        var c = Config.shell.toggles.recordingStopCommand;
        if (c) Quickshell.execDetached(c);
        refreshSoon.restart();
    }

    function refresh() {
        nightCheck.running = true;
        dndCheck.running = true;
        if (recordingCommand) recCheck.running = true;
    }

    Timer { id: refreshSoon; interval: 600; onTriggered: root.refresh() }
    Timer {
        interval: Config.shell.toggles.pollInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
