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

    // Touchpad: lo stato e il comando vengono dal backend del compositor (oggi Sway).
    readonly property bool touchpadAvailable: SwayBackend.active && SwayBackend.hasTouchpad
    readonly property bool touchpad: touchpadAvailable && SwayBackend.touchpadOn
    function toggleTouchpad() { if (touchpadAvailable) SwayBackend.setTouchpad(!SwayBackend.touchpadOn); }

    readonly property var recordingCommand: Config.shell.toggles.recordingCommand

    // "Resta sveglio" può essere anche esterno (es. uno script che ferma swayidle): `awakeCommand` esce con 0 se è
    // attivo, `awakeToggleCommand` lo commuta. Senza questi comandi vale solo l'inibitore interno di Vela.
    property bool awakeExternal: false
    readonly property bool awakeOn: awake || awakeExternal
    readonly property var awakeCommand: Config.shell.toggles.awakeCommand
    readonly property var awakeToggleCommand: Config.shell.toggles.awakeToggleCommand

    function setAwake(on) { awake = on; }
    function toggleAwake() {
        if (awakeToggleCommand) { Quickshell.execDetached(awakeToggleCommand); refreshSoon.restart(); }
        else awake = !awake;
    }
    // Spegne "resta sveglio" da qualunque origine sia attivo.
    function stopAwake() {
        awake = false;
        if (awakeExternal && awakeToggleCommand) { Quickshell.execDetached(awakeToggleCommand); refreshSoon.restart(); }
    }

    Process {
        id: awakeCheck
        command: root.awakeCommand ? root.awakeCommand : ["false"]
        onExited: code => root.awakeExternal = (root.awakeCommand !== null && code === 0)
    }

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

    // --- non disturbare: stato interno se il server di notifiche è di Vela, altrimenti dunst ---
    Connections {
        target: Notifications
        enabled: Notifications.active
        function onDndChanged() { root.dnd = Notifications.dnd; }
    }
    Component.onCompleted: if (Notifications.active) { dnd = Notifications.dnd; dndAvailable = true; }
    // dunstctl può mancare (altro server di notifiche, o nessuno): lo si cerca una volta sola,
    // senza riprovare a ogni controllo periodico.
    property bool hasDunstctl: false
    Process {
        command: ["sh", "-c", "command -v dunstctl"]
        running: true
        onExited: code => { root.hasDunstctl = (code === 0); if (root.hasDunstctl) dndCheck.running = true; }
    }
    Process {
        id: dndCheck
        command: ["dunstctl", "is-paused"]
        stdout: StdioCollector {
            onStreamFinished: { if (!Notifications.active) { root.dnd = text.trim() === "true"; root.dndAvailable = true; } }
        }
    }

    function toggleDnd() {
        if (Notifications.active) { Notifications.dnd = !Notifications.dnd; return; }
        if (!dndAvailable || !hasDunstctl) return;
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
        if (hasDunstctl && !Notifications.active) dndCheck.running = true;
        if (recordingCommand) recCheck.running = true;
        if (awakeCommand) awakeCheck.running = true;
        if (SwayBackend.active) SwayBackend.refreshInputs();      // anche per touchpad e layout di tastiera
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
