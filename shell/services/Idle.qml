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
import "../core/lock.js" as Lock

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
    // Secondi di dissolvenza prima del blocco per inattività (0 = subito, senza dissolvenza).
    readonly property int fadeSecs: typeof cfg.fadeSeconds === "number" ? Math.max(0, Math.min(30, Math.round(cfg.fadeSeconds))) : 0

    // Un monitor per tempo: Variants lo ricrea quando il tempo cambia (il timeout di un IdleMonitor già creato non viene riletto).
    Variants {
        model: root.enabled && root.lockSecs > 0 ? [root.lockSecs] : []
        IdleMonitor {
            required property int modelData
            timeout: modelData
            respectInhibitors: true
            onIsIdleChanged: if (isIdle) root.beginLock(); else root.cancelFade()
        }
    }
    Variants {
        model: root.enabled && root.screenOffSecs > 0 ? [root.screenOffSecs] : []
        IdleMonitor {
            required property int modelData
            timeout: modelData
            respectInhibitors: true
            onIsIdleChanged: Compositor.setScreensPower(!isIdle)    // spenge da inattivo, riaccende all'attività
        }
    }
    Variants {
        model: root.enabled && root.suspendSecs > 0 ? [root.suspendSecs] : []
        IdleMonitor {
            required property int modelData
            timeout: modelData
            respectInhibitors: true
            onIsIdleChanged: if (isIdle) root.suspend()
        }
    }

    // Blocco per inattività: prima la dissolvenza (se attiva), poi il blocco; l'attività la annulla.
    property bool fading: false
    function beginLock() {
        if (fadeSecs <= 0) { lock(); return; }
        fading = true;
        fadeTimer.interval = fadeSecs * 1000;
        fadeTimer.restart();
    }
    function cancelFade() {
        fadeTimer.stop();
        release.stop();
        fading = false;
    }
    Timer {
        id: fadeTimer
        onTriggered: { root.lock(); release.restart(); }
    }
    // Il buio resta ancora un attimo, finché la schermata di blocco non è su.
    Timer { id: release; interval: 1500; onTriggered: root.fading = false }

    // Comando di blocco con i colori del tema (solo se è il predefinito `swaylock -f`, vedi core/lock.js).
    function themedLock() {
        return Lock.themedCommand(lockCommand, {
            background: Theme.background.toString(), surface: Theme.surface.toString(), foreground: Theme.foreground.toString(),
            accent: Theme.accent.toString(), error: Theme.error.toString(), font: Theme.fontFamily
        });
    }

    // Blocca lo schermo, salvo che un blocco dello stesso utente sia già attivo (il comando è un array: nessuna shell sulla stringa).
    function lock() { Quickshell.execDetached(Lock.waitLockArgv(themedLock())); }

    // Sospende (unico ingresso: menu, pannello utente, IPC e inattività). Prima il blocco, e si sospende solo se è confermato:
    // se il comando di blocco fallisce il PC resta acceso con un avviso, mai sospeso e sbloccato.
    function suspend() {
        if (locker.running) return;
        locker.command = Lock.waitLockArgv(themedLock());
        locker.running = true;
    }
    Process {
        id: locker
        onExited: code => {
            if (code === 0) Quickshell.execDetached(["loginctl", "suspend"]);
            else Quickshell.execDetached(["notify-send", "-a", "Vela", "-u", "critical", "-i", "dialog-warning", I18n.tr("Sospensione annullata"),
                I18n.tr("Il blocco dello schermo non è partito: non sospendo con lo schermo sbloccato.")]);
        }
    }

    // Blocco prima di ogni sospensione, anche se non parte da Vela (coperchio chiuso, tasto di accensione, altri programmi):
    // swayidle tiene l'inibitore di elogind finché il blocco non è fatto (core/lock.js). Si ricrea se cambia il comando di blocco.
    readonly property bool lockOnSleep: enabled && cfg.lockOnSleep !== false
    Variants {
        model: root.lockOnSleep ? [JSON.stringify(Lock.sleepLockCommand(root.themedLock()))] : []
        Process {
            required property string modelData
            command: JSON.parse(modelData)
            running: true
        }
    }

    // Un altro gestore dell'inattività in esecuzione causerebbe doppioni: il pannello lo segnala.
    // Il nostro swayidle (solo `before-sleep`, senza timeout) non conta.
    property bool externalRunning: false
    Process {
        id: probe
        command: ["pgrep", "-f", "^swayidle .* timeout "]
        onExited: code => root.externalRunning = (code === 0)
    }
    function checkExternal() { if (!probe.running) probe.running = true; }
    Component.onCompleted: checkExternal()
}
