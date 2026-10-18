// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Apre il monitor di sistema configurato (es. ["foot", "-e", "btop"]); senza configurazione non fa nulla.
pragma Singleton
import QtQuick
import Quickshell
import "../core"

Singleton {
    function open() {
        var c = Config.shell.stats.monitorCommand;
        if (c) Quickshell.execDetached(c);
    }
}
