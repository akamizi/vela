// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Selettore grafico dello sfondo (scheda Sfondo delle Impostazioni): griglia di miniature delle immagini trovate nelle
// cartelle immagini dell'utente e in quelle di sistema. ←/→/↑/↓ si muove, Invio sceglie, Esc chiude; il clic sceglie.
// Scrive solo `sway.wallpaper.path`: l'applicazione la fa il backend Sway come per il percorso scritto a mano.
import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "../../services"
import "../../ui"

FocusScope {
    id: picker

    signal closed()

    readonly property string home: Quickshell.env("HOME")
    readonly property string current: Config.sway.wallpaper.path || ""
    readonly property int cellWidth: 200
    readonly property int cellHeight: 128
    property var files: []
    property bool scanning: false

    function begin() {
        files = [];
        scanning = true;
        scan.running = false;
        scan.running = true;
        forceActiveFocus();
    }

    function choose(path) {
        if (!path) return;
        Settings.set("sway", "wallpaper.path", path);
        closed();
    }

    // Cartelle cercate (due livelli, niente seguire link verso altrove); i file con caratteri che Sway non accetta si scartano.
    Process {
        id: scan
        command: ["sh", "-c",
                  "for d in \"$HOME/Immagini/backgrounds\" \"$HOME/Pictures/backgrounds\" /usr/share/backgrounds /usr/share/vela/assets; do " +
                  "[ -d \"$d\" ] && find \"$d\" -maxdepth 2 -type f -size +60k \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) ; " +
                  "done | sort -u | head -400"]
        stdout: StdioCollector {
            onStreamFinished: {
                picker.files = text.split("\n").filter(function (p) { return p !== "" && SwayBackend.safe(p); });
                picker.scanning = false;
                var i = picker.files.indexOf(picker.current);
                grid.currentIndex = i >= 0 ? i : 0;
            }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.background }

    BarText {
        id: title
        anchors { left: parent.left; leftMargin: Theme.padding; top: parent.top; topMargin: Theme.padding }
        text: I18n.tr("Scegli lo sfondo")
        font.bold: true
    }
    BarText {
        anchors { right: parent.right; rightMargin: Theme.padding; verticalCenter: title.verticalCenter }
        color: Theme.dim
        text: I18n.tr("Invio sceglie · Esc torna indietro")
    }

    BarText {
        anchors.centerIn: parent
        visible: !picker.scanning && picker.files.length === 0
        color: Theme.dim
        text: I18n.tr("Nessuna immagine in Immagini/backgrounds o /usr/share/backgrounds")
    }

    GridView {
        id: grid
        anchors { left: parent.left; right: parent.right; top: title.bottom; bottom: parent.bottom; margins: Theme.padding }
        clip: true
        cellWidth: picker.cellWidth + Theme.gap
        cellHeight: picker.cellHeight + Theme.rowHeight
        model: picker.files
        focus: true
        keyNavigationEnabled: true
        highlightMoveDuration: 0

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { picker.closed(); event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { picker.choose(picker.files[currentIndex]); event.accepted = true; }
        }

        delegate: Item {
            id: cell
            required property string modelData
            required property int index
            readonly property bool cursor: GridView.isCurrentItem
            readonly property bool active: modelData === picker.current
            width: grid.cellWidth
            height: grid.cellHeight + Theme.rowHeight

            Rectangle {
                id: frame
                width: picker.cellWidth; height: picker.cellHeight
                radius: Theme.radius
                color: Theme.surface
                border.width: cell.cursor || cell.active ? 2 : 1
                border.color: cell.cursor ? Theme.accent : (cell.active ? Theme.foreground : Theme.border)
                Image {
                    anchors { fill: parent; margins: 3 }
                    source: "file://" + cell.modelData
                    sourceSize: Qt.size(picker.cellWidth * 2, picker.cellHeight * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }
            BarText {
                anchors { left: frame.left; right: frame.right; top: frame.bottom; topMargin: 2 }
                elide: Text.ElideMiddle
                color: cell.cursor ? Theme.foreground : Theme.muted
                text: cell.modelData.split("/").pop()
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: grid.currentIndex = cell.index
                onClicked: picker.choose(cell.modelData)
            }
        }
    }
}
