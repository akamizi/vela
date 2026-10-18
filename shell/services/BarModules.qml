// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Elenco degli elementi di barra disponibili: i file plugins/bar/widgets/<Nome>Widget.qml.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var names: []

    Process {
        command: ["ls", Quickshell.shellDir + "/plugins/bar/widgets"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.split("\n").forEach(function (f) {
                    var m = /^([A-Z][A-Za-z]*)Widget\.qml$/.exec(f);
                    if (m) out.push(m[1]);
                });
                out.sort();
                root.names = out;
            }
        }
    }
}
