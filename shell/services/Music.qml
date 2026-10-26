// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Musica locale: la cartella dell'utente (XDG_MUSIC_DIR, in qualunque lingua; poi ~/Musica e ~/Music) con i suoi file audio.
// Si ricontrolla a ogni apertura del menu e del pannello, senza osservare i file. La riproduzione passa dal Player condiviso.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/musiclib.js" as MusicLib

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string userDirsPath: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/user-dirs.dirs"

    property string rootDir: ""              // la cartella Musica trovata, "" se non esiste
    readonly property bool available: rootDir !== ""
    property var folders: []                 // [{rel, path, files: [{name, path}]}]
    property bool scanning: false

    // Si legge user-dirs.dirs ogni volta (cat: un FileView potrebbe restituire il testo di prima; se il file manca il testo è vuoto
    // e restano ~/Musica e ~/Music), poi si prova ogni candidata.
    function refresh() {
        if (!dirsRead.running) dirsRead.running = true;
    }

    Process {
        id: dirsRead
        command: ["cat", root.userDirsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var cands = MusicLib.musicDirCandidates(text, root.home);
                // Gli argomenti sono separati: nessun nome di cartella passa per una shell.
                probe.command = ["sh", "-c", 'for d in "$@"; do [ -d "$d" ] && { printf %s "$d"; exit 0; }; done; exit 1', "sh"].concat(cands);
                probe.running = true;
            }
        }
    }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                var d = text.trim() === "" ? "" : text;
                if (d !== root.rootDir) { root.rootDir = d; root.folders = []; }
                if (d !== "" && root.wantScan) root.scan();
            }
        }
        onExited: code => { if (code !== 0) { root.rootDir = ""; root.folders = []; } }
    }

    // Rilegge la cartella: da chiamare all'apertura del pannello (dopo refresh).
    property bool wantScan: false
    function scan() {
        if (rootDir === "") { wantScan = true; return; }
        wantScan = false;
        if (finder.running) return;
        scanning = true;
        finder.command = ["find", rootDir, "-type", "f", "-print0"];
        finder.running = true;
    }
    function open() { wantScan = true; refresh(); }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                var paths = text.split("\0").filter(function (p) { return p !== ""; });
                root.folders = MusicLib.groupFolders(paths, root.rootDir);
                root.scanning = false;
            }
        }
        onExited: code => { if (code !== 0) root.scanning = false; }
    }

    function folderName(f) { return f.rel === "" ? I18n.tr("Musica") : f.rel; }

    function playFolder(f) {
        if (!f || f.files.length === 0) return;
        Player.play("music", folderName(f), f.path, ["--"].concat(f.files.map(function (x) { return x.path; })));
    }
    function playFile(file) {
        if (!file) return;
        Player.play("music", file.name, file.path, ["--", file.path]);
    }

    Connections {
        target: Player
        function onStateChanged() {
            if (Player.kind === "music" && Player.state === "playing")
                Quickshell.execDetached(["notify-send", "-a", "Vela", "-i", "media-playback-start", I18n.tr("Musica"), "▶ " + Player.name]);
        }
        function onExited(kind, code, wanted) {
            if (kind === "music" && !wanted && code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Vela", "-u", "critical", "-i", "dialog-error", I18n.tr("Musica"), I18n.tr("Errore: impossibile riprodurre") + " " + Player.name]);
        }
    }
}
