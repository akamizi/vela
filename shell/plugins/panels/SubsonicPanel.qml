// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello Subsonic: gli ultimi 100 album del server, poi i brani. Invio apre l'album o riproduce («Tutto l'album» o un brano;
// di nuovo = ferma). Esc: cancella il filtro, torna agli album, chiude. Gli errori (permessi del file, campi mancanti,
// rete, server) si leggono nel pannello.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

BrowserPanel {
    id: panel
    name: "subsonic"
    icon: Icons.music
    title: "Subsonic"

    readonly property bool mine: Player.kind === "subsonic"
    readonly property bool inAlbum: Subsonic.albumId !== ""
    canGoBack: inAlbum
    iconColor: Player.state === "error" && mine ? Theme.warning : Player.playing && mine ? Theme.accent : Theme.muted
    meta: mine && Player.state !== "stopped" ? Player.name : I18n.tr("ferma")
    detail: mine ? (Player.state === "starting" ? I18n.tr("connessione…") : Player.state === "playing" ? I18n.tr("in riproduzione") : Player.state === "error" ? Player.error : "") : ""
    stopVisible: Player.playing && mine
    footerHint: panel.inAlbum
        ? I18n.tr("Invio riproduce / ferma · digita per filtrare · ↑/↓ scorri · Esc torna agli album")
        : I18n.tr("Invio apre l'album · digita per filtrare · ↑/↓ scorri · Esc chiude")

    function problem() {
        switch (Subsonic.status) {
        case "none": return I18n.tr("File delle credenziali non trovato: %1", Subsonic.envPath);
        case "perms": return I18n.tr("Il file delle credenziali deve essere leggibile solo da te: chmod 600 %1", Subsonic.envPath);
        case "incomplete": return I18n.tr("Nel file delle credenziali mancano: %1", Subsonic.cred.missing.join(", "));
        case "offline": return I18n.tr("Server non raggiungibile");
        case "error": return Subsonic.error;
        case "loading": return I18n.tr("Caricamento…");
        }
        return "";
    }

    rows: {
        var q = query.trim().toLowerCase();
        var bad = problem();
        if (bad !== "" && !(Subsonic.status === "loading" && (inAlbum ? Subsonic.songs.length > 0 : Subsonic.albums.length > 0)))
            return [{ kind: "message", text: bad, key: "m:problem" }];
        var out = [];
        if (Player.playing && mine) out.push({ kind: "stop", key: "stop" });
        if (!inAlbum) {
            var al = Subsonic.albums.filter(function (a) { return q === "" || a.label.toLowerCase().indexOf(q) >= 0; });
            if (Subsonic.albums.length === 0) return out.concat([{ kind: "message", text: I18n.tr("Nessun album"), key: "m:none" }]);
            if (al.length === 0) return out.concat([{ kind: "message", text: I18n.tr("Nessun risultato"), key: "m:nomatch" }]);
            out.push({ kind: "header", label: I18n.tr("Album recenti"), key: "h:albums" });
            al.forEach(function (a) { out.push({ kind: "item", label: a.label, album: a, key: "a:" + a.id, selected: mine && Player.playing && Player.key === a.id }); });
        } else {
            out.push({ kind: "header", label: Subsonic.albumLabel, key: "h:album" });
            if (q === "") out.push({ kind: "item", label: I18n.tr("Tutto l'album"), icon: Icons.play, all: true, key: "all",
                                     selected: mine && Player.playing && Player.key === Subsonic.albumId });
            Subsonic.songs.filter(function (s) { return q === "" || s.label.toLowerCase().indexOf(q) >= 0; }).forEach(function (s) {
                out.push({ kind: "item", label: s.label, song: s, key: "s:" + s.id, selected: mine && Player.playing && Player.key === s.id });
            });
        }
        return out;
    }

    onOpened: { Subsonic.closeAlbum(); Subsonic.open(); }
    onBack: { Subsonic.closeAlbum(); query = ""; }
    onActivated: row => {
        if (row.kind === "stop") { Player.stop(); return; }
        if (row.album) { Subsonic.openAlbum(row.album.id, row.album.label); query = ""; return; }
        if (row.all) { if (Player.key === Subsonic.albumId && Player.playing) Player.stop(); else Subsonic.playAlbum(); return; }
        if (row.song) { if (Player.key === row.song.id && Player.playing) Player.stop(); else Subsonic.playSong(row.song); }
    }
}
