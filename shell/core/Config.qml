// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Punto unico di accesso alla configurazione a strati.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "jsonc.js" as Jsonc

Singleton {
    id: root

    // I default stanno accanto al codice (../config/defaults), sia nel repository
    // sia nell'installazione di sistema (/usr/share/vela/{shell,config}).
    readonly property string defaultsDir: Quickshell.shellDir + "/../config/defaults"
    // VELA_USER_DIR serve solo ai test.
    readonly property string userDir: Quickshell.env("VELA_USER_DIR")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/vela")

    // Impostazioni scritte dal pannello: ~/.config/vela/settings.jsonc, con le chiavi "shell" e "theme".
    // Vela scrive solo questo file, mai quelli scritti a mano dall'utente (D-021).
    property var settingsData: ({})

    FileView {
        id: settingsFile
        path: root.userDir + "/settings.jsonc"
        printErrors: false
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.readSettings()
        onLoadFailed: root.readSettings()
    }

    function readSettings() {
        var obj = {};
        try {
            var t = settingsFile.text();
            if (t.trim() !== "") obj = Jsonc.parse(t);
        } catch (e) {
            console.warn("[vela] settings.jsonc non leggibile, ignorato: " + e.message);
        }
        settingsData = (obj && typeof obj === "object" && !Array.isArray(obj)) ? obj : {};
    }

    // Scrive le impostazioni: aggiorna subito lo stato (anteprima) e salva su disco.
    property string pendingText: ""
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.userDir]
        onExited: settingsFile.setText(root.pendingText)
    }
    function writeSettings(obj) {
        settingsData = obj;
        pendingText = JSON.stringify(obj, null, 2) + "\n";
        mkdir.running = true;
    }

    readonly property ConfigLayer shellLayer: ConfigLayer {
        name: "shell"; defaultsDir: root.defaultsDir; userDir: root.userDir
        settings: root.settingsData.shell || ({})
    }
    readonly property ConfigLayer themeLayer: ConfigLayer {
        name: "theme"; defaultsDir: root.defaultsDir; userDir: root.userDir
        settings: root.settingsData.theme || ({})
    }

    readonly property ConfigLayer swayLayer: ConfigLayer {
        name: "sway"; defaultsDir: root.defaultsDir; userDir: root.userDir
        settings: root.settingsData.sway || ({})
    }

    readonly property ConfigLayer menuLayer: ConfigLayer {
        name: "menu"; mode: "menu"; defaultsDir: root.defaultsDir; userDir: root.userDir
    }

    readonly property var menu: menuLayer.data
    readonly property var shell: shellLayer.data
    readonly property var theme: themeLayer.data
    readonly property var sway: swayLayer.data
    readonly property var warnings: shellLayer.warnings.concat(themeLayer.warnings, menuLayer.warnings, swayLayer.warnings)
}
