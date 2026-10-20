// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Server di notifiche integrato (D-006). Sostituisce dunst: org.freedesktop.Notifications può avere un solo
// proprietario, quindi resta spento (`notifications.enabled: false`) finché dunst è attivo (D-008).
// Il testo delle notifiche è l'unico input non fidato di rilievo: si mostra sempre come testo semplice.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../core"

Singleton {
    id: root

    readonly property bool active: Config.shell.notifications.enabled
    property bool dnd: false          // non disturbare: le notifiche normali vengono scartate in silenzio
    readonly property var tracked: loader.item ? loader.item.trackedNotifications : null

    // Gruppi per mittente (`appName`): una scheda per mittente, non una per notifica. Il modello elenca solo i mittenti
    // presenti, in ordine di primo arrivo, e si aggiorna per inserimenti e rimozioni: le schede non si ricreano a ogni
    // notifica (niente sfarfallio, il passaggio del mouse resta). Le notifiche di un gruppo, dalla più vecchia: itemsOf().
    readonly property ListModel groups: ListModel {}

    function itemsOf(key) {
        var all = tracked ? tracked.values : [];
        return all.filter(function (n) { return n.appName === key; });
    }

    function syncGroups() {
        var all = tracked ? tracked.values : [];
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
                n.tracked = true;
            }
        }
    }
}
