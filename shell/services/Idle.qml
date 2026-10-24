// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Inattività gestita da Vela (D-024): blocco dello schermo, spegnimento e sospensione dopo X, Y, Z minuti.
// Usa IdleMonitor (ext-idle-notify) e rispetta gli inibitori di idle (finestre a schermo intero, "Resta sveglio").
// Spento di default: va attivato quando non c'è un altro gestore (es. swayidle).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core"

Singleton {
    id: root

    readonly property var cfg: Config.shell.idle
    readonly property bool enabled: cfg.enabled === true || ((cfg.enabled === null || cfg.enabled === undefined) && Quickshell.env("VELA_SESSION") === "1")
    readonly property var lockCommand: Array.isArray(cfg.lockCommand) && cfg.lockCommand.length > 0 ? cfg.lockCommand : ["swaylock", "-f"]

    function secs(minutes) { return typeof minutes === "number" && minutes > 0 ? Math.round(minutes * 60) : 0; }

    // Ogni tempo ha due valori: a batteria (`xxxMinutes`) e con l'alimentatore (`xxxMinutesOnAc`). Un PC senza batteria è sempre "a rete".
    // Se la chiave `…OnAc` manca vale quella a batteria.
    readonly property bool onAc: Power.onAc
    function minutes(base) {
        var v = onAc ? cfg[base + "OnAc"] : undefined;
        return typeof v === "number" ? v : cfg[base];
    }
    readonly property int lockSecs: secs(minutes("lockMinutes"))
    readonly property int screenOffSecs: secs(minutes("screenOffMinutes"))
    readonly property int suspendSecs: secs(minutes("suspendMinutes"))

    IdleMonitor {
        enabled: root.enabled && root.lockSecs > 0
        timeout: Math.max(1, root.lockSecs)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lock()
    }
    IdleMonitor {
        enabled: root.enabled && root.screenOffSecs > 0
        timeout: Math.max(1, root.screenOffSecs)
        respectInhibitors: true
        onIsIdleChanged: Compositor.setScreensPower(!isIdle)    // spenge da inattivo, riaccende all'attività
    }
    IdleMonitor {
        enabled: root.enabled && root.suspendSecs > 0
        timeout: Math.max(1, root.suspendSecs)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.suspend()
    }

    // Blocca lo schermo, salvo che un blocco sia già attivo (il comando è un array: nessuna shell sulla stringa).
    function lock() {
        var name = String(lockCommand[0]).split("/").pop();
        Quickshell.execDetached(["sh", "-c", 'pgrep -x "$1" >/dev/null 2>&1 || exec "$@"', "sh", name].concat(lockCommand));
    }

    // Sospende dopo aver avviato il blocco (si ritrova la schermata di blocco al risveglio).
    function suspend() {
        lock();
        suspendDelay.restart();
    }
    Timer { id: suspendDelay; interval: 1200; onTriggered: Quickshell.execDetached(["loginctl", "suspend"]) }

    // Un altro gestore dell'inattività in esecuzione causerebbe doppioni: il pannello lo segnala.
    property bool externalRunning: false
    Process {
        id: probe
        command: ["pgrep", "-x", "swayidle"]
        onExited: code => root.externalRunning = (code === 0)
    }
    function checkExternal() { if (!probe.running) probe.running = true; }
    Component.onCompleted: checkExternal()
}
