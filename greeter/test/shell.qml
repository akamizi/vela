// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Prova guidata del greeter (D-055): invia utente, password e richieste di spegnimento senza simulare tasti; si usa con test/fake-greetd.py.
import QtQuick
import Quickshell
import ".."

ShellRoot {
    FloatingWindow {
        visible: true
        title: "Vela greeter (prova)"
        Greeter { id: g; anchors.fill: parent; focus: true }
        Timer { interval: 1000; running: true; onTriggered: { console.log("tema", g.cAccent, g.fontFamily, "utente iniziale:", g.user, "sessione:", g.session ? g.session.name : "-"); g.requestPower("reboot"); } }
        Timer { interval: 1300; running: true; onTriggered: g.requestPower("reboot") }
        Timer { interval: 1600; running: true; onTriggered: g.requestPower("poweroff") }
        Timer { interval: 2200; running: true; onTriggered: { if (g.user === "") { g.user = "mizi"; g.submitUser(); } g.cycleSession(1); } }
        Timer { interval: 3500; running: true; onTriggered: { g.password = "sbagliata"; g.submitPassword(); } }
        Timer { interval: 6500; running: true; onTriggered: { g.password = "ok"; g.submitPassword(); } }
    }
}
