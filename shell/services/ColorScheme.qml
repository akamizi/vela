// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Chiaro/scuro per le app GTK, Firefox, Chromium e libadwaita (D-063): imposta `org.gnome.desktop.interface color-scheme` in
// accordo con il tema di Vela (sfondo più scuro del testo = `prefer-dark`). Le app lo leggono dal portale
// (`org.freedesktop.appearance`). Non tocca il tema GTK né le icone. Si applica all'avvio e a ogni cambio di tema, e scrive solo
// se il valore è diverso; `colorScheme.sync: false` lo spegne. Senza `gsettings` non fa niente.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/colorscheme.js" as CS

Singleton {
    id: root

    readonly property bool enabled: Config.shell.colorScheme.sync === true
    readonly property var wanted: CS.schemeFor(Config.theme.colors.background, Config.theme.colors.foreground)
    readonly property var schema: ["org.gnome.desktop.interface", "color-scheme"]

    function apply() {
        if (!enabled || wanted === null || reader.running || writer.running) return;
        reader.running = true;
    }

    onWantedChanged: apply()
    onEnabledChanged: apply()
    Component.onCompleted: apply()

    Process {
        id: reader
        command: ["gsettings", "get"].concat(root.schema)
        stdout: StdioCollector {
            onStreamFinished: {
                if (CS.cleanValue(text) !== root.wanted) {
                    writer.command = ["gsettings", "set"].concat(root.schema).concat([root.wanted]);
                    writer.running = true;
                }
            }
        }
    }

    Process { id: writer }
}
