// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Pannello Musica: cartelle della cartella Musica dell'utente, poi i brani. Invio apre la cartella o riproduce
// («Tutta la cartella» o un brano; di nuovo = ferma). Esc: cancella il filtro, torna alle cartelle, chiude.
import QtQuick
import Quickshell
import "../../core"
import "../../core/icons.js" as Icons
import "../../services"
import "../../ui"

BrowserPanel {
    id: panel
    name: "music"
    icon: Icons.music
    title: I18n.tr("Musica")

    property var folder: null            // cartella aperta (livello 2), null = elenco delle cartelle
    readonly property bool mine: Player.kind === "music"
    canGoBack: folder !== null
    iconColor: Player.state === "error" && mine ? Theme.warning : Player.playing && mine ? Theme.accent : Theme.muted
    meta: mine && Player.state !== "stopped" ? Player.name : I18n.tr("ferma")
    detail: mine ? (Player.state === "starting" ? I18n.tr("connessione…") : Player.state === "playing" ? I18n.tr("in riproduzione") : Player.state === "error" ? Player.error : "") : ""
    stopVisible: Player.playing && mine
    footerHint: panel.canGoBack
        ? I18n.tr("Invio riproduce / ferma · digita per filtrare · ↑/↓ scorri · Esc torna alle cartelle")
        : I18n.tr("Invio apre la cartella · digita per filtrare · ↑/↓ scorri · Esc chiude")

    rows: {
        var q = query.trim().toLowerCase();
        if (!Music.available)
            return [{ kind: "message", text: I18n.tr("Cartella Musica non trovata"), key: "m:nodir" }];
        var out = [];
        if (Player.playing && mine) out.push({ kind: "stop", key: "stop" });
        if (folder === null) {
            var fl = Music.folders.filter(function (f) { return q === "" || Music.folderName(f).toLowerCase().indexOf(q) >= 0; });
            if (Music.folders.length === 0)
                return out.concat([{ kind: "message", text: Music.scanning ? I18n.tr("Lettura della cartella…") : I18n.tr("Nessun brano trovato"), key: "m:none" }]);
            if (fl.length === 0) return out.concat([{ kind: "message", text: I18n.tr("Nessun risultato"), key: "m:nomatch" }]);
            out.push({ kind: "header", label: I18n.tr("Cartelle"), key: "h:dirs" });
            fl.forEach(function (f) {
                out.push({ kind: "item", label: Music.folderName(f), icon: Icons.music, f: f, key: "d:" + f.path,
                           selected: mine && Player.playing && Player.key === f.path });
            });
        } else {
            out.push({ kind: "header", label: Music.folderName(folder), key: "h:folder" });
            if (q === "") out.push({ kind: "item", label: I18n.tr("Tutta la cartella"), icon: Icons.play, all: true, key: "all",
                                     selected: mine && Player.playing && Player.key === folder.path });
            folder.files.filter(function (x) { return q === "" || x.name.toLowerCase().indexOf(q) >= 0; }).forEach(function (x) {
                out.push({ kind: "item", label: x.name, file: x, key: "f:" + x.path, selected: mine && Player.playing && Player.key === x.path });
            });
            if (out.length <= 2 && q !== "") out.push({ kind: "message", text: I18n.tr("Nessun risultato"), key: "m:nomatch" });
        }
        return out;
    }

    onOpened: { folder = null; Music.open(); }
    onBack: { folder = null; query = ""; }
    onActivated: row => {
        if (row.kind === "stop") { Player.stop(); return; }
        if (row.f) { folder = row.f; query = ""; return; }
        if (row.all) { if (Player.key === folder.path && Player.playing) Player.stop(); else Music.playFolder(folder); return; }
        if (row.file) { if (Player.key === row.file.path && Player.playing) Player.stop(); else Music.playFile(row.file); }
    }
}
