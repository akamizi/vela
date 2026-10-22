// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Punto d'ingresso di Vela: ogni funzione è un plugin attivabile da configurazione.
import QtQuick
import Quickshell
import Quickshell.Io
// Quickshell sintetizza i qmldir seguendo gli import visibili da qui: i widget della barra
// si caricano dinamicamente, quindi ui e services vanno importati esplicitamente.
import "core"
import "ui"
import "core/qtstyle.js" as QtStyle
import "services"
import "plugins/bar"
import "plugins/menu"
import "plugins/panels"
import "plugins/osd"
import "plugins/notifications"

ShellRoot {
    // I servizi sono singleton creati al primo uso: l'inattività deve esistere fin dall'avvio.
    readonly property bool idleManaged: Idle.enabled
    readonly property bool daemonManaged: Daemon.enabled    // il demone dati (D-039) parte con Vela

    Loader {
        active: Config.shell.bar.enabled
        sourceComponent: Bar {}
    }

    Loader {
        active: Config.shell.menu.enabled
        sourceComponent: Menu {}
    }

    Loader {
        active: Config.shell.panels.network.enabled
        sourceComponent: NetworkPanel {}
    }

    Loader {
        active: Config.shell.panels.bluetooth.enabled
        sourceComponent: BluetoothPanel {}
    }

    Loader {
        active: Config.shell.panels.audio.enabled
        sourceComponent: AudioPanel {}
    }

    Loader {
        active: Config.shell.panels.settings.enabled
        sourceComponent: SettingsPanel {}
    }

    Loader {
        active: Config.shell.panels.shortcuts.enabled
        sourceComponent: ShortcutsPanel {}
    }

    Loader {
        active: Config.shell.panels.power.enabled
        sourceComponent: PowerPanel {}
    }

    Loader {
        active: Config.shell.panels.battery.enabled && BatteryLimit.supported
        sourceComponent: BatteryPanel {}
    }

    Loader {
        active: Config.shell.panels.weather.enabled
        sourceComponent: WeatherPanel {}
    }

    Loader {
        active: Config.shell.panels.calendar.enabled
        sourceComponent: CalendarPanel {}
    }

    Loader {
        active: Config.shell.panels.brightness.enabled
        sourceComponent: BrightnessPanel {}
    }

    Loader {
        active: Config.shell.panels.display.enabled
        sourceComponent: DisplayPanel {}
    }

    Loader {
        active: Config.shell.panels.printers.enabled
        sourceComponent: PrintersPanel {}
    }

    Loader {
        active: Config.shell.panels.services.enabled
        sourceComponent: ServicesPanel {}
    }

    Loader {
        active: Config.shell.panels.radio.enabled
        sourceComponent: RadioPanel {}
    }

    Loader {
        active: Config.shell.osd.enabled
        sourceComponent: Osd {}
    }

    Loader {
        active: Config.shell.notifications.enabled
        sourceComponent: Popups {}
    }

    // Comandi da scorciatoie Sway: `vela ipc call <target> <funzione>`, es. `vela ipc call bar toggle`.
    IpcHandler {
        target: "bar"
        function toggle(): void { Runtime.barVisible = !Runtime.barVisible; }
    }
    IpcHandler {
        target: "menu"
        function toggle(): void { Runtime.toggleMenu("menu"); }   // menu completo
        function apps(): void { Runtime.toggleMenu("apps"); }     // solo applicazioni
        function calc(): void { Runtime.toggleMenu("calc"); }     // calcolatrice
        function close(): void { Runtime.closeMenu(); }
    }
    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            if (MenuModel.availablePanels.indexOf(name) >= 0) Runtime.togglePanel(name);
        }
        function close(): void { Runtime.closePanel(); }
    }
    IpcHandler {
        target: "toggles"
        function awake(): void { Toggles.toggleAwake(); }
        function status(): string {    // stato in JSON, per script e diagnostica
            return JSON.stringify({ night: Toggles.night, dnd: Toggles.dnd, awake: Toggles.awakeOn, recording: Toggles.recording });
        }
        function refresh(): void { Toggles.refresh(true); }   // per gli script che cambiano uno stato esterno
        function night(): void { Toggles.toggleNight(); }
        function dnd(): void { Toggles.toggleDnd(); }
        function touchpad(): void { Toggles.toggleTouchpad(); }
        function batteryLimit(): void { BatteryLimit.toggleLimit(); }
    }
    IpcHandler {
        target: "theme"    // `qss`: foglio di stile Qt dal tema (lo usa `vela theme qt`)
        function qss(): string { return QtStyle.qss(Config.theme); }
    }

    IpcHandler {
        target: "services"    // servizi runit: `status` (JSON), `run start|stop|restart|enable|disable <servizio>` (apre un terminale con doas/sudo)
        function status(): string { return JSON.stringify({ available: Services.available, items: Services.items }); }
        function refresh(): void { Services.refresh(); }
        function run(action: string, name: string): void { Services.act(action, name); }   // apre il terminale con doas/sudo (chiede la password)
    }

    IpcHandler {
        target: "printers"    // stampanti: `status` (JSON), `default <nome>`, `pause <nome>` (ferma/riprende), `cancel <id>`, `scan`, `add <indirizzo>`, `remove <nome>`
        function status(): string {
            return JSON.stringify({ up: Printers.schedulerUp, default: Printers.defaultName, admin: Printers.admin, error: Printers.error,
                                    printers: Printers.printers, jobs: Printers.jobs, devices: Printers.devices, scanning: Printers.scanning });
        }
        function refresh(): void { Printers.refresh(); }
        function setDefault(name: string): void { Printers.setDefault(name); }
        function pause(name: string): void {
            for (var i = 0; i < Printers.printers.length; i++)
                if (Printers.printers[i].name === name) { Printers.togglePause(name, Printers.printers[i].state); return; }
        }
        function cancel(id: string): void { Printers.cancelJob(id); }
        function scan(): void { Printers.scan(); }
        function add(address: string): void { var u = Printers.normalizeAddress(address); if (u !== "") Printers.addPrinter(u, ""); else Printers.error = I18n.tr("Indirizzo non valido"); }
        function remove(name: string): void { Printers.removePrinter(name); }
    }

    IpcHandler {
        target: "display"    // schermi: `mode internal|external|extend|mirror`, `place <schermo> left|right|above|below` (con conferma di 15 s), `keep`, `revert`, `status`
        function mode(name: string): void { SwayBackend.applyDisplayMode(name); }
        function place(screen: string, side: string): void { SwayBackend.placeOutput(screen, side); }   // con due schermi: left|right|above|below
        function keep(): void { SwayBackend.confirm(); }
        function revert(): void { SwayBackend.revert(); }
        function status(): string {
            return JSON.stringify({ mode: SwayBackend.displayMode, pending: SwayBackend.pending !== null, countdown: SwayBackend.countdown,
                                    outputs: SwayBackend.outputs.map(function (o) { return { name: o.name, active: o.active, mode: o.mode, scale: o.scale, x: o.x, y: o.y }; }) });
        }
    }
    IpcHandler {
        target: "layout"    // disposizione delle finestre del contenitore col focus: next, prev, set <nome>, status
        function next(): void { Compositor.cycleWindowLayout(1); }
        function prev(): void { Compositor.cycleWindowLayout(-1); }
        function set(name: string): void { Compositor.setWindowLayout(name); }
        function status(): string { return Compositor.windowLayout; }
    }
    IpcHandler {
        target: "session"
        function logout(): void { Session.request("logout"); }
        function reboot(): void { Session.request("reboot"); }
        function poweroff(): void { Session.request("poweroff"); }
        function status(): string { return JSON.stringify({ pending: Session.pending, windows: Session.windowCount }); }
    }
    IpcHandler {
        target: "daemon"
        function status(): string { return Daemon.status(); }
    }
    IpcHandler {
        target: "radio"
        function stop(): void { Radio.stop(); }
        function play(name: string): void {
            var st = Radio.stations.filter(function (s) { return s.name === name; })[0];
            if (st) Radio.play(st);
        }
    }
    // Tasti multimediali e di schermo da Sway: `vela ipc call audio raise`, `brightness up`, `screens on`.
    IpcHandler {
        target: "audio"
        function raise(): void { Audio.change(Config.shell.audio.step, Config.shell.audio.maxVolume); }
        function lower(): void { Audio.change(-Config.shell.audio.step, Config.shell.audio.maxVolume); }
        function mute(): void { Audio.toggleMute(); }
        function micMute(): void { Audio.toggleMicMute(); }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.change(Config.shell.brightness.step); }
        function down(): void { Brightness.change(-Config.shell.brightness.step); }
    }
    IpcHandler {
        target: "keyboard"
        function next(): void { SwayBackend.switchLayout(1); }
        function prev(): void { SwayBackend.switchLayout(-1); }
        function status(): string {    // stato in JSON, per script e diagnostica
            return JSON.stringify({ layouts: SwayBackend.keyboard ? SwayBackend.keyboard.layouts : [], current: SwayBackend.layoutName,
                                    touchpad: SwayBackend.hasTouchpad ? SwayBackend.touchpadOn : null, viaDaemon: SwayBackend.daemonInputs });
        }
    }
    IpcHandler {
        target: "screens"
        function on(): void { Compositor.setScreensPower(true); }
        function off(): void { Compositor.setScreensPower(false); }
    }
    IpcHandler {
        target: "idle"
        function lock(): void { Idle.lock(); }
        function suspend(): void { Idle.suspend(); }
    }
}
