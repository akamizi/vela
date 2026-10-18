// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Punto unico di accesso alla configurazione a strati.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // I default stanno accanto al codice (../config/defaults), sia nel repository
    // sia nell'installazione di sistema (/usr/share/vela/{shell,config}).
    readonly property string defaultsDir: Quickshell.shellDir + "/../config/defaults"
    // VELA_USER_DIR serve solo ai test.
    readonly property string userDir: Quickshell.env("VELA_USER_DIR")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/vela")

    readonly property ConfigLayer shellLayer: ConfigLayer {
        name: "shell"; defaultsDir: root.defaultsDir; userDir: root.userDir
    }
    readonly property ConfigLayer themeLayer: ConfigLayer {
        name: "theme"; defaultsDir: root.defaultsDir; userDir: root.userDir
    }

    readonly property ConfigLayer menuLayer: ConfigLayer {
        name: "menu"; mode: "menu"; defaultsDir: root.defaultsDir; userDir: root.userDir
    }

    readonly property var menu: menuLayer.data
    readonly property var shell: shellLayer.data
    readonly property var theme: themeLayer.data
    readonly property var warnings: shellLayer.warnings.concat(themeLayer.warnings, menuLayer.warnings)
}
