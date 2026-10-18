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
            // Le più recenti sotto; se sono troppe si mostrano le ultime `maxVisible`.
            model: Notifications.tracked

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property var n: modelData
                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                readonly property string iconSource: {
                    if (n.image) return n.image;
                    if (!n.appIcon) return "";
                    if (n.appIcon.charAt(0) === "/") return "file://" + n.appIcon;
                    return Quickshell.iconPath(n.appIcon, true);
                }

                visible: index >= list.count - win.maxVisible
                width: column.width
                height: visible ? content.implicitHeight + Theme.padding * 2 : 0
                color: Theme.surface
                radius: Theme.radius
                border.width: 1
                border.color: critical ? Theme.error : Theme.border

                // Scade da sé, salvo le critiche. 0 = predefinito, -1 = a discrezione del server.
                Timer {
                    interval: card.n.expireTimeout > 0 ? card.n.expireTimeout * 1000 : Config.shell.notifications.timeout
                    running: card.visible && !card.critical && !hover.hovered
                    onTriggered: card.n.expire()
                }

                HoverHandler { id: hover }
                TapHandler { onTapped: card.n.dismiss() }

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
                            width: parent.width
                            text: card.n.summary
                            font.bold: true
                            elide: Text.ElideRight
                            color: card.critical ? Theme.error : Theme.foreground
                        }
                        BarText {
                            visible: card.n.body !== ""
                            width: parent.width
                            text: card.n.body
                            color: Theme.muted
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignTop
                        }
                        Row {
                            visible: card.n.actions.length > 0
                            spacing: Theme.spacing
                            Repeater {
                                model: card.n.actions
                                delegate: Rectangle {
                                    required property var modelData
                                    height: Theme.rowHeight - 8
                                    width: label.implicitWidth + Theme.padding * 2
                                    radius: Theme.radius
                                    color: Theme.border
                                    BarText { id: label; anchors.centerIn: parent; text: parent.modelData.text }
                                    TapHandler { onTapped: parent.modelData.invoke() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
