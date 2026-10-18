// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Punto d'ingresso di Vela: ogni funzione è un plugin attivabile da configurazione.
import QtQuick
import Quickshell
import "core"
import "plugins/bar"

ShellRoot {
    Loader {
        active: Config.shell.bar.enabled
        sourceComponent: Bar {}
    }
}
