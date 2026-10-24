// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Greeter di Vela (D-055): un'unica finestra a schermo intero dentro un compositor minimo (per esempio `cage -s -- quickshell -p <cartella>`).
import Quickshell

ShellRoot {
    FloatingWindow {
        visible: true
        title: "Vela greeter"
        Greeter { anchors.fill: parent; focus: true }
    }
}
