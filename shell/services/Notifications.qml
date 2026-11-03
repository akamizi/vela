// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Server di notifiche integrato (D-006). Sostituisce dunst: org.freedesktop.Notifications può avere un solo
// proprietario, quindi resta spento (`notifications.enabled: false`) finché dunst è attivo (D-008).
// Il testo delle notifiche è l'unico input non fidato di rilievo: si mostra sempre come testo semplice.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../core"
import "../core/notifhold.js" as Hold

Singleton {
    id: root

    // Attivo se abilitato, oppure nella sessione «Vela» (VELA_SESSION=1, impostata da vela-session) salvo `inVelaSession: false`.
    readonly property bool active: Config.shell.notifications.enabled
        || (Quickshell.env("VELA_SESSION") === "1" && Config.shell.notifications.inVelaSession)
    property bool dnd: false          // non disturbare: le notifiche normali vengono scartate in silenzio
    readonly property var tracked: loader.item ? loader.item.trackedNotifications : null

    // Gruppi per mittente (`appName`): una scheda per mittente, non una per notifica. Il modello elenca solo i mittenti
    // presenti, in ordine di primo arrivo, e si aggiorna per inserimenti e rimozioni: le schede non si ricreano a ogni
    // notifica (niente sfarfallio, il passaggio del mouse resta). Le notifiche di un gruppo, dalla più vecchia: itemsOf().
    readonly property ListModel groups: ListModel {}

    // Schermo intero (D-065): con la finestra in primo piano a schermo intero le notifiche normali non compaiono ma restano in
    // coda (al massimo `heldMax`, le più vecchie si chiudono) e compaiono quando si esce. Le critiche passano sempre. Diverso dal
    // non disturbare manuale, che le scarta. Una notifica che un'app sostituisce mentre si è a schermo intero si aggiorna comunque.
    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen === true : false
    readonly property bool holding: Config.shell.notifications.fullscreenDnd === true && fullscreen
    property var heldIds: []          // id delle notifiche trattenute, in ordine di arrivo
    onHoldingChanged: if (!holding && heldIds.length > 0) { heldIds = []; syncGroups(); }

    // Notifiche da mostrare: quelle tracciate meno le trattenute.
    function shown() {
        var all = tracked ? tracked.values : [];
        return all.filter(function (n) { return !Hold.isHeld(heldIds, n.id); });
    }

    function itemsOf(key) {
        return shown().filter(function (n) { return n.appName === key; });
    }

    function syncGroups() {
        var all = shown();
        var present = {};
        for (var i = 0; i < all.length; i++) present[all[i].appName] = true;
        for (var j = groups.count - 1; j >= 0; j--)
            if (!present[groups.get(j).key]) groups.remove(j);
        var have = {};
        for (var k = 0; k < groups.count; k++) have[groups.get(k).key] = true;
        for (var m = 0; m < all.length; m++) {
            var key = all[m].appName;
            if (!have[key]) { groups.append({ key: key }); have[key] = true; }
        }
    }

    Connections {
        target: root.tracked
        function onValuesChanged() { root.syncGroups(); }
    }
    onTrackedChanged: syncGroups()

    LazyLoader {
        id: loader
        loading: root.active
        NotificationServer {
            keepOnReload: false
            bodySupported: true
            bodyMarkupSupported: false      // niente markup: dichiararlo evita che le app lo mandino
            bodyHyperlinksSupported: false
            bodyImagesSupported: false
            actionsSupported: true
            imageSupported: true
            persistenceSupported: false

            onNotification: n => {
                // In "non disturbare" passano solo le urgenze critiche.
                if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;
                if (root.holding && n.urgency !== NotificationUrgency.Critical) {
                    // Una trattenuta che l'app ha chiuso nel frattempo esce dalla coda. Qui, non in syncGroups: `tracked = true` aggiorna
                    // l'elenco solo a gestore finito, e una pulizia fatta mentre si chiudono le più vecchie toglierebbe la nuova.
                    var live = {};
                    (root.tracked ? root.tracked.values : []).forEach(function (x) { live[x.id] = true; });
                    var base = root.heldIds.filter(function (id) { return live[id] === true; });
                    // Si segna prima di tracciarla, così non compare nemmeno per un istante
                    var r = Hold.hold(base, n.id, Config.shell.notifications.heldMax);
                    root.heldIds = r.ids;
                    n.tracked = true;
                    r.dropped.forEach(function (id) {
                        (root.tracked ? root.tracked.values : []).forEach(function (x) { if (x.id === id) x.dismiss(); });
                    });
                    return;
                }
                n.tracked = true;
            }
        }
    }
}
