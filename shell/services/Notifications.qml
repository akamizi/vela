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
