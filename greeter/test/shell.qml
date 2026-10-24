// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Prova guidata del greeter (D-055): invia utente e password senza simulare tasti; si usa con test/fake-greetd.py.
import QtQuick
import Quickshell
import ".."

ShellRoot {
    FloatingWindow {
        visible: true
        title: "Vela greeter (prova)"
        Greeter { id: g; anchors.fill: parent; focus: true }
        Timer { interval: 2000; running: true; onTriggered: { g.user = "mizi"; g.submitUser(); } }
        Timer { interval: 3500; running: true; onTriggered: { g.password = "sbagliata"; g.submitPassword(); } }
        Timer { interval: 6500; running: true; onTriggered: { g.password = "ok"; g.submitPassword(); } }
    }
}
