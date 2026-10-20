// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Indicatori raggruppati (come in Omarchy): un solo elemento con i simboli dei modi accesi (non disturbare, luce
// notturna, resta sveglio, registrazione). Un clic su un simbolo lo accende o lo spegne. Con la barra sotto il mouse
// compaiono anche quelli spenti (`bar.indicators.peek`), così si possono accendere da qui; `alwaysShow` li tiene sempre.
// Quali indicatori e in che ordine: `bar.indicators.items` (Recording, Dnd, NightLight, Awake).
// Gli elementi singoli (Dnd, NightLight, Awake, Recording) restano disponibili e si possono usare al posto di questo.
BarItem {
    id: root

    readonly property var cfg: Config.shell.bar.indicators
    readonly property bool peeking: cfg.alwaysShow === true
        || (cfg.peek === true && QsWindow.window && QsWindow.window.pointerInside === true)
    property string hoveredName: ""

    // Stato di ogni indicatore: `on` acceso, `available` se si può accendere da qui, icona, colore e testi.
    function info(name) {
        switch (name) {
        case "Recording":
            return { on: Toggles.recording, available: false, icon: Icons.recording, color: Theme.error,
                     tip: I18n.tr("Registrazione in corso") };
        case "Dnd":
            return { on: Toggles.dnd, available: Notifications.active || Toggles.dndAvailable, icon: Icons.dnd, color: Theme.accent,
                     tip: Toggles.dnd ? I18n.tr("Non disturbare attivo") : I18n.tr("Non disturbare spento: clic per attivare") };
        case "NightLight":
            return { on: Toggles.night, available: MenuModel.found["gammastep"] === true, icon: Icons.night, color: Theme.accent,
                     tip: Toggles.night ? I18n.tr("Luce notturna attiva") : I18n.tr("Luce notturna spenta: clic per attivare") };
        case "Awake":
            return { on: Toggles.awakeOn, available: true, icon: Icons.awake, color: Theme.warning,
                     tip: Toggles.awakeOn ? I18n.tr("Resta sveglio: il blocco dello schermo è sospeso. Clic per disattivare.")
                                          : I18n.tr("Resta sveglio spento: clic per attivare") };
        }
        return null;
    }

    function activate(name) {
        if (name === "Recording") Toggles.stopRecording();
        else if (name === "Dnd") Toggles.toggleDnd();
        else if (name === "NightLight") Toggles.toggleNight();
        else if (name === "Awake") { if (Toggles.awakeOn) Toggles.stopAwake(); else Toggles.toggleAwake(); }
    }

    // Quanti simboli si vedono ora (le larghezze nulle non occupano spazio).
    readonly property int shown: {
        var n = 0, names = cfg.items;
        for (var i = 0; i < names.length; i++) {
            var d = info(names[i]);
            if (d && (d.on || (peeking && d.available))) n++;
        }
        return n;
    }

    visible: shown > 0
    tooltip: hoveredName !== "" && info(hoveredName) ? info(hoveredName).tip : ""
    clickable: false

    // L'inibitore dell'inattività deve stare in una finestra: quella della barra (come l'elemento Awake).
    IdleInhibitor {
        window: root.QsWindow.window
        enabled: Toggles.awake && root.cfg.items.indexOf("Awake") >= 0
    }

    Repeater {
        model: root.cfg.items
        delegate: Item {
            id: cell
            required property string modelData
            readonly property var d: root.info(modelData)
            readonly property bool show: d !== null && (d.on || (root.peeking && d.available))
            visible: show
            width: show ? glyph.implicitWidth + Theme.gap : 0
            height: Theme.barHeight

            BarIcon {
                id: glyph
                anchors.centerIn: parent
                text: cell.d ? cell.d.icon : ""
                color: cell.d && cell.d.on ? cell.d.color : Theme.dim
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onContainsMouseChanged: root.hoveredName = containsMouse ? cell.modelData : (root.hoveredName === cell.modelData ? "" : root.hoveredName)
                onClicked: root.activate(cell.modelData)
            }
        }
    }
}
