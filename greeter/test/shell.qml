// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Prova guidata del greeter (D-055): invia utente, password e richieste di spegnimento senza simulare tasti; si usa con test/fake-greetd.py.
import QtQuick
import Quickshell
import ".."

ShellRoot {
    FloatingWindow {
        id: win
        visible: true
        title: "Vela greeter (prova)"
        Greeter { id: g; anchors.fill: parent; focus: true }
        // Spegni/Riavvia si provano SOLO se i comandi sono sostituiti da finti (VELA_GREETER_POWEROFF e VELA_GREETER_REBOOT):
        // senza, il test eseguirebbe `loginctl reboot` sul PC vero (è già successo il 2026-10-24).
        readonly property bool powerSafe: !!Quickshell.env("VELA_GREETER_POWEROFF") && !!Quickshell.env("VELA_GREETER_REBOOT")
        Timer { interval: 1000; running: true; onTriggered: { console.log("tema", g.cAccent, g.fontFamily, "utente iniziale:", g.user, "sessione:", g.session ? g.session.name : "-"); if (win.powerSafe) g.requestPower("reboot"); } }
        Timer { interval: 1300; running: true; onTriggered: if (win.powerSafe) g.requestPower("reboot") }
        Timer { interval: 1600; running: true; onTriggered: if (win.powerSafe) g.requestPower("poweroff") }
        Timer { interval: 2200; running: true; onTriggered: { if (g.user === "") { g.user = "mizi"; g.submitUser(); } g.cycleSession(1); } }
        Timer { interval: 3500; running: true; onTriggered: { g.password = "sbagliata"; g.submitPassword(); } }
        Timer { interval: 6500; running: true; onTriggered: { g.password = "ok"; g.submitPassword(); } }
    }
}
