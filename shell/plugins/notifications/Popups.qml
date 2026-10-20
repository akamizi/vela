// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Notifiche a comparsa, in alto a destra. Clic = chiudi; i pulsanti eseguono le azioni dell'app.
// La finestra lascia passare i clic ovunque tranne sulle schede.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../../core"
import "../../services"
import "../../ui"

PanelWindow {
    id: win

    readonly property int cardWidth: 360
    readonly property int maxVisible: Config.shell.notifications.maxVisible

    screen: Compositor.focusedScreen
    visible: list.count > 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: Config.shell.bar.position === "top" ? Theme.barHeight + Theme.panelMargin : Theme.panelMargin; right: Theme.panelMargin }
    implicitWidth: cardWidth
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "vela-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: column }

    Column {
        id: column
        width: win.cardWidth
        spacing: Theme.spacing

        Repeater {
            id: list
            // Una scheda per mittente; le più recenti sotto; se sono troppe si mostrano le ultime `maxVisible`.
            model: Notifications.groups

            delegate: Rectangle {
                id: card
                required property string key
                required property int index
                // Notifiche del mittente, dalla più vecchia; `n` è l'ultima ed è quella mostrata (testo e pulsanti).
                readonly property var items: Notifications.itemsOf(key)
                readonly property var n: items.length > 0 ? items[items.length - 1] : null
                readonly property bool critical: items.some(function (x) { return x.urgency === NotificationUrgency.Critical; })
                // Notifiche precedenti con testo diverso dall'ultima (le identiche si fondono nel contatore), le più recenti prima.
                readonly property var earlier: {
                    var out = [];
                    for (var i = items.length - 2; i >= 0 && out.length < 2; i--) {
                        var x = items[i];
                        if ((x.summary !== n.summary || x.body !== n.body) && out.indexOf(x.summary) < 0) out.push(x.summary);
                    }
                    return out;
                }
                readonly property string iconSource: {
                    if (!n) return "";
                    if (n.image) return n.image;
                    if (!n.appIcon) return "";
                    if (n.appIcon.charAt(0) === "/") return "file://" + n.appIcon;
                    return Quickshell.iconPath(n.appIcon, true);
                }

                // Durata in ms. Con 0 o -1 vale il predefinito. Quickshell 0.3.2 passa `expireTimeout` così come lo manda l'app,
                // cioè in millisecondi (misurato: `notify-send -t 3000` dà 3000), pur documentandolo in secondi: i valori
                // piccoli (< 100) si leggono come secondi, per non rompersi se Quickshell lo correggerà.
                readonly property int lifeMs: {
                    var t = n ? n.expireTimeout : 0;
                    if (!(t > 0)) return Config.shell.notifications.timeout;
                    return Math.round(t >= 100 ? t : t * 1000);
                }

                function closeAll(expire) {
                    var all = items.slice();
                    for (var i = 0; i < all.length; i++) { if (expire) all[i].expire(); else all[i].dismiss(); }
                }

                visible: n !== null && index >= list.count - win.maxVisible
                width: column.width
                height: visible ? content.implicitHeight + Theme.padding * 2 : 0
                color: Theme.surface
                radius: Theme.radius
                border.width: 1
                border.color: critical ? Theme.error : Theme.softBorder

                // barra laterale: colore dell'urgenza
                Rectangle {
                    width: 3
                    height: parent.height - (Theme.radius > 0 ? Theme.radius : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    color: card.critical ? Theme.error : Theme.accent
                }

                // Scade da sé, salvo le critiche; l'arrivo di una nuova notifica del gruppo riparte da capo.
                // 0 = predefinito, -1 = a discrezione del server. Alla scadenza scade tutto il gruppo.
                // Il timer si governa solo da `rearm()`: restart() romperebbe un legame dichiarativo di `running`.
                Timer {
                    id: life
                    interval: card.lifeMs
                    onTriggered: card.closeAll(true)
                }
                readonly property bool wantTimer: visible && !critical && !hover.hovered
                function rearm() { if (wantTimer) life.restart(); else life.stop(); }
                onWantTimerChanged: rearm()
                onNChanged: rearm()
                Component.onCompleted: rearm()

                HoverHandler { id: hover }
                TapHandler { onTapped: card.closeAll(false) }    // il clic chiude tutto il gruppo

                Row {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.padding }
                    spacing: Theme.padding

                    Image {
                        visible: card.iconSource !== ""
                        width: visible ? 40 : 0
                        height: 40
                        source: card.iconSource
                        sourceSize: Qt.size(40, 40)
                        fillMode: Image.PreserveAspectFit
                    }

                    Column {
                        width: parent.width - (card.iconSource !== "" ? 40 + Theme.padding : 0)
                        spacing: Theme.gap

                        BarText {
                            visible: card.n !== null && (card.n.appName !== "" || card.items.length > 1)
                            width: parent.width
                            text: card.n ? (card.n.appName.toUpperCase() + (card.items.length > 1 ? (card.n.appName !== "" ? "  ×" : "×") + card.items.length : "")) : ""
                            color: Theme.dim
                            font.pixelSize: Theme.fontSize - 2
                            font.bold: true
                            font.letterSpacing: 1.2
                            elide: Text.ElideRight
                        }
                        BarText {
                            width: parent.width
                            text: card.n ? card.n.summary : ""
                            font.bold: true
                            elide: Text.ElideRight
                            color: card.critical ? Theme.error : Theme.foreground
                        }
                        BarText {
                            visible: card.n !== null && card.n.body !== ""
                            width: parent.width
                            text: card.n ? card.n.body : ""
                            color: Theme.muted
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignTop
                        }
                        Repeater {
                            model: card.earlier
                            delegate: BarText {
                                required property string modelData
                                width: parent.width
                                text: "· " + modelData
                                color: Theme.dim
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                            }
                        }
                        Row {
                            visible: card.n !== null && card.n.actions.length > 0
                            spacing: Theme.spacing
                            Repeater {
                                model: card.n ? card.n.actions : []
                                delegate: PanelActionButton {
                                    required property var modelData
                                    text: modelData.text
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
