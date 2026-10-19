// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Punto d'ingresso di Vela: ogni funzione è un plugin attivabile da configurazione.
import QtQuick
import Quickshell
import Quickshell.Io
// Quickshell sintetizza i qmldir seguendo gli import visibili da qui: i widget della barra
// si caricano dinamicamente, quindi ui e services vanno importati esplicitamente.
import "core"
import "ui"
import "services"
import "plugins/bar"
import "plugins/menu"
import "plugins/panels"
import "plugins/osd"
import "plugins/notifications"

ShellRoot {
    // I servizi sono singleton creati al primo uso: l'inattività deve esistere fin dall'avvio.
    readonly property bool idleManaged: Idle.enabled

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
        function refresh(): void { Toggles.refresh(); }   // per gli script che cambiano uno stato esterno
        function night(): void { Toggles.toggleNight(); }
        function dnd(): void { Toggles.toggleDnd(); }
    }
    IpcHandler {
        target: "radio"
        function stop(): void { Radio.stop(); }
        function play(name: string): void {
            var st = Radio.stations.filter(function (s) { return s.name === name; })[0];
            if (st) Radio.play(st);
        }
    }
    IpcHandler {
        target: "idle"
        function lock(): void { Idle.lock(); }
        function suspend(): void { Idle.suspend(); }
    }
}
