// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Servizio compositor (D-016): workspace, finestra attiva. Unico punto che conosce Sway;
// i plugin non importano Quickshell.I3 né chiamano swaymsg.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland

Singleton {
    id: root

    // Backend implementato in questo file (D-022). Compositors.qml dice se coincide col compositor della sessione.
    readonly property string backend: "sway"

    // Titolo della finestra attiva (protocollo wlr-foreign-toplevel, valido per più compositor).
    readonly property string activeTitle: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""

    // Workspace dello schermo dato, ordinati per numero. `persistent` è l'elenco di numeri
    // da mostrare sempre, anche se vuoti. Ogni voce: {num, name, present, focused, urgent}.
    function workspacesFor(screen, persistent) {
        var monitor = I3.monitorFor(screen);
        var all = I3.workspaces.values;
        var byNum = {};
        var list = [];
        for (var i = 0; i < all.length; i++) {
            var ws = all[i];
            if (monitor && ws.monitor !== monitor) continue;
            list.push({ num: ws.num, name: ws.name, present: true, focused: ws.focused, urgent: ws.urgent });
            byNum[ws.num] = true;
        }
        for (var j = 0; j < persistent.length; j++) {
            var n = persistent[j];
            if (!byNum[n]) list.push({ num: n, name: String(n), present: false, focused: false, urgent: false });
        }
        list.sort(function (a, b) { return a.num - b.num; });
        return list;
    }

    function activate(num) {
        // num è sempre un intero (viene da I3 o dalla configurazione): nessuna stringa esterna nel comando.
        if (Number.isInteger(num) && num >= 0) I3.dispatch("workspace number " + num);
    }

    function cycle(direction) {
        I3.dispatch(direction > 0 ? "workspace prev_on_output" : "workspace next_on_output");
    }

    // Disposizione del contenitore col focus (splith, splitv, tabbed, stacking, floating; vuota se non si sa).
    // Arriva dal demone dati (modulo sway) a ogni cambio di focus, finestre e workspace e quando scatta una scorciatoia
    // `layout …`; un comando dato da altri programmi (swaymsg) si vede al primo evento successivo.
    property string windowLayout: ""
    readonly property bool windowLayoutKnown: Daemon.ready("sway") && windowLayout !== ""
    readonly property var windowLayouts: ["splith", "splitv", "tabbed", "stacking"]

    function readDaemonLayout() {
        var st = Daemon.states.sway;
        windowLayout = st && typeof st.layout === "string" ? st.layout : "";
    }
    Component.onCompleted: readDaemonLayout()    // il singleton può nascere dopo il primo stato del demone
    Connections {
        target: Daemon
        function onModuleState(module) { if (module === "sway") root.readDaemonLayout(); }
    }

    // Imposta una disposizione (nome dall'elenco chiuso) e la mostra subito: Sway non avvisa dei cambi fatti via IPC.
    function setWindowLayout(name) {
        if (windowLayouts.indexOf(name) < 0) return false;
        I3.dispatch("layout " + name);
        windowLayout = name;
        return true;
    }

    // Passa alla disposizione successiva (direction > 0) o precedente; non fa nulla su una finestra flottante.
    function cycleWindowLayout(direction) {
        if (windowLayout === "floating") return false;
        var n = windowLayouts.length;
        var i = windowLayouts.indexOf(windowLayout);
        if (i < 0) i = direction > 0 ? -1 : 0;
        return setWindowLayout(windowLayouts[(i + (direction > 0 ? 1 : n - 1)) % n]);
    }

    // Schermo su cui sta il focus (per aprire il menu dove guarda l'utente).
    readonly property var focusedScreen: {
        var m = I3.focusedMonitor;
        var screens = Quickshell.screens;
        for (var i = 0; m && i < screens.length; i++) if (screens[i].name === m.name) return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    // Accende o spegne tutti gli schermi (inattività). Valore booleano: nessuna stringa esterna nel comando.
    function setScreensPower(on) { I3.dispatch("output * power " + (on === true ? "on" : "off")); }

    // Comandi del compositor che il menu può invocare (elenco chiuso, nessuna stringa libera).
    function run(command) {
        if (command === "logout") { I3.dispatch("exit"); return true; }
        if (command === "reload") { I3.dispatch("reload"); return true; }
        return false;
    }
}
