// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Subsonic: album e brani di un server Subsonic/Navidrome. Le credenziali stanno in ~/.config/subsonic-mpv/env (SUBSONIC_URL,
// SUBSONIC_USER, SUBSONIC_PASS), file dell'utente che Vela non scrive e rifiuta se i permessi non sono 600.
// La password resta in memoria e non esce: alle richieste va solo il token; mpv riceve un file di playlist (permessi 600 in
// $XDG_RUNTIME_DIR) e non un indirizzo con token negli argomenti. La riproduzione passa dal Player condiviso.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/subsonic.js" as Sub

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string envPath: home + "/.config/subsonic-mpv/env"
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // Una playlist per ogni riproduzione (contiene il token): `files` tiene i percorsi da cancellare.
    property var files: []
    property int playlistSerial: 0

    // Il file env esiste (anche se i permessi o i campi non vanno: il pannello lo spiega).
    property bool available: false
    // "none" | "perms" | "incomplete" | "loading" | "ready" | "offline" | "error"
    property string status: "none"
    property string error: ""
    property var albums: []                  // [{id, label}]
    property var songs: []                   // [{id, label, artist, title}]
    property string albumId: ""
    property string albumLabel: ""
    property bool wantLoad: false

    property var cred: ({ url: "", user: "", pass: "", missing: [] })
    property int serial: 0                   // scarta le risposte di richieste superate

    Component.onCompleted: removeFiles("all")

    // Lettura del file: prima riga i permessi (ottale), poi il contenuto. Senza file cat/stat falliscono.
    function refresh() { if (!reader.running) reader.running = true; }
    function open() { wantLoad = true; refresh(); }

    Process {
        id: reader
        command: ["sh", "-c", 'stat -c %a "$1" && cat "$1"', "sh", root.envPath]
        stdout: StdioCollector {
            onStreamFinished: {
                var nl = text.indexOf("\n");
                var perms = nl < 0 ? "" : text.slice(0, nl).trim();
                root.available = nl >= 0;
                if (!root.available) { root.status = "none"; return; }
                root.cred = Sub.parseEnv(text.slice(nl + 1));
                if (perms !== "600") { root.status = "perms"; root.error = ""; root.albums = []; return; }
                if (root.cred.missing.length > 0) { root.status = "incomplete"; root.albums = []; return; }
                if (!Sub.validUrl(root.cred.url)) { root.status = "error"; root.error = I18n.tr("SUBSONIC_URL non valido (serve http o https)"); return; }
                if (root.status === "none" || root.status === "perms" || root.status === "incomplete") root.status = "ready";
                if (root.wantLoad) root.loadAlbums();
            }
        }
        onExited: code => { if (code !== 0) { root.available = false; root.status = "none"; root.albums = []; } }
    }

    function salt() {
        var s = "";
        for (var i = 0; i < 12; i++) s += "0123456789abcdef".charAt(Math.floor(Math.random() * 16));
        return s;
    }
    function auth() { return Sub.authQuery(cred.user, cred.pass, salt(), function (s) { return Qt.md5(s); }); }

    function get(url, done) {
        var mine = ++serial;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || mine !== root.serial) return;
            if (xhr.status !== 200) { root.status = "offline"; return; }
            var json = null;
            try { json = JSON.parse(xhr.responseText); } catch (e) { json = null; }
            done(json);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function loadAlbums() {
        wantLoad = false;
        if (status === "perms" || status === "incomplete") return;
        status = "loading";
        get(Sub.albumListUrl(cred.url, auth()), function (json) {
            var r = Sub.parseAlbums(json);
            if (!r.ok) { root.status = "error"; root.error = r.error; root.albums = []; return; }
            root.albums = r.albums; root.status = "ready"; root.error = "";
        });
    }

    function openAlbum(id, label) {
        status = "loading"; albumId = id; albumLabel = label; songs = [];
        get(Sub.albumUrl(cred.url, id, auth()), function (json) {
            var r = Sub.parseSongs(json);
            if (!r.ok) { root.status = "error"; root.error = r.error; root.albumId = ""; return; }
            root.songs = r.songs; root.status = "ready"; root.error = "";
        });
    }
    function closeAlbum() { albumId = ""; albumLabel = ""; songs = []; }

    // --- riproduzione: playlist con permessi 600, cancellata alla fine ---------------------------------------------
    property var pendingPlay: null
    function writePlaylist(name, key, entries) {
        var path = runtimeDir + "/vela-subsonic-" + (++playlistSerial) + ".m3u";
        pendingPlay = { name: name, key: key, path: path };
        files = files.concat([path]);
        var text = Sub.playlistText(entries.map(function (s) {
            return { artist: s.artist, title: s.title, url: Sub.streamUrl(cred.url, s.id, auth()) };
        }));
        // umask 077 prima di creare il file; il testo arriva da stdin, mai dagli argomenti del processo.
        writer.command = ["sh", "-c", 'rm -f "$1"; umask 077; cat > "$1"', "sh", path];
        writer.pendingText = text;
        writer.running = true;
    }
    function playAlbum() { if (songs.length > 0) writePlaylist(albumLabel, albumId, songs); }
    function playSong(song) { if (song) writePlaylist(song.artist !== "" ? song.artist + " - " + song.title : song.title, song.id, [song]); }

    Process {
        id: writer
        property string pendingText: ""
        stdinEnabled: true
        onStarted: { write(pendingText); stdinEnabled = false; pendingText = ""; }
        onExited: code => {
            stdinEnabled = true;
            if (code === 0 && root.pendingPlay) Player.play("subsonic", root.pendingPlay.name, root.pendingPlay.key, ["--", root.pendingPlay.path]);
            root.pendingPlay = null;
        }
    }

    // Cancella le playlist di cui non c'è più bisogno: "all" tutte (anche quelle rimaste da una sessione precedente), "old" tutte
    // tranne l'ultima scritta (un'altra riproduzione di Subsonic sta per partire con quella).
    function removeFiles(which) {
        var keep = which === "old" && files.length > 0 ? files[files.length - 1] : "";
        var gone = files.filter(function (f) { return f !== keep; });
        files = keep === "" ? [] : [keep];
        // Con "all" ci sono anche i file di una sessione precedente: si cancellano per modello.
        cleanup.command = which === "all"
            ? ["sh", "-c", 'rm -f "$1"/vela-subsonic-*.m3u', "sh", root.runtimeDir]
            : ["rm", "-f", "--"].concat(gone);
        if (which === "all" || gone.length > 0) cleanup.running = true;
    }
    Process { id: cleanup }

    Connections {
        target: Player
        function onStateChanged() {
            if (Player.kind === "subsonic" && Player.state === "playing")
                Quickshell.execDetached(["notify-send", "-a", "Vela", "-i", "media-playback-start", "Subsonic", "▶ " + Player.name]);
        }
        function onExited(kind, code, wanted, next) {
            if (kind !== "subsonic") return;
            // L'uscita di mpv (fine, Stop, errore o cambio di flusso) chiude con la sua playlist; se subito dopo parte un'altra
            // riproduzione di Subsonic si tiene l'ultima scritta.
            removeFiles(next === "subsonic" ? "old" : "all");
            if (!wanted && code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Vela", "-u", "critical", "-i", "dialog-error", "Subsonic", I18n.tr("Errore: impossibile riprodurre") + " " + Player.name]);
        }
    }
}
