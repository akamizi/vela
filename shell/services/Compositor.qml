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

    // Titolo della finestra attiva (protocollo wlr-foreign-toplevel, valido per più compositor).
    readonly property string activeTitle: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""

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
}
