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

ShellRoot {
    Loader {
        active: Config.shell.bar.enabled
        sourceComponent: Bar {}
    }

    Loader {
        active: Config.shell.menu.enabled
        sourceComponent: Menu {}
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
        target: "toggles"
        function awake(): void { Toggles.setAwake(!Toggles.awake); }
        function night(): void { Toggles.toggleNight(); }
        function dnd(): void { Toggles.toggleDnd(); }
    }
}
