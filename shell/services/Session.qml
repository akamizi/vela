// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Fine sessione con chiusura ordinata delle finestre: spegni, riavvia, esci. Prima chiede a ogni finestra di chiudersi
// (come il pulsante di chiusura: l'app può salvare o chiedere conferma), poi esegue l'azione quando non ne resta nessuna.
// Se dopo `session.closeTimeout` ci sono ancora finestre (per esempio una domanda "salvare?" senza risposta) l'azione
// è annullata e compare una notifica: niente dati persi in silenzio.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

Singleton {
    id: root

    readonly property bool enabled: Config.shell.session.closeWindows === true
    property string pending: ""                        // azione in attesa che le finestre si chiudano
    readonly property var windows: ToplevelManager.toplevels.values
    readonly property int windowCount: windows.length

    // Azioni ammesse (elenco chiuso: nessuna stringa esterna nel comando).
    function finish(kind) {
        if (kind === "poweroff") Quickshell.execDetached(["loginctl", "poweroff"]);
        else if (kind === "reboot") Quickshell.execDetached(["loginctl", "reboot"]);
        else if (kind === "logout") return Compositor.run("logout");
        else return false;
        return true;
    }

    function request(kind) {
        if (kind !== "poweroff" && kind !== "reboot" && kind !== "logout") return false;
        if (pending !== "") return true;                // già in corso
        if (!enabled || windowCount === 0) return finish(kind);
        pending = kind;
        var list = windows.slice();
        for (var i = 0; i < list.length; i++) list[i].close();
        giveUp.interval = Math.max(1000, Config.shell.session.closeTimeout);
        giveUp.restart();
        return true;
    }

    onWindowCountChanged: {
        if (pending === "" || windowCount > 0) return;
        giveUp.stop();
        var kind = pending;
        pending = "";
        finish(kind);
    }

    Timer {
        id: giveUp
        onTriggered: {
            var n = root.windowCount;
            root.pending = "";
            if (n > 0) Quickshell.execDetached(["notify-send", "-a", "Vela", "-u", "critical",
                I18n.tr("Operazione annullata"),
                I18n.tr("Ci sono ancora %1 finestre aperte: chiudile o rispondi alle domande e riprova.", String(n))]);
        }
    }
}
