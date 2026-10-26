// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Subsonic (API 1.16.1): lettura del file di credenziali, indirizzi con token e lettura delle risposte.
// Logica pura: nessun accesso a rete o file. La password non esce da qui: negli indirizzi c'è solo token e salt.
.pragma library

var API_VERSION = "1.16.1";
var CLIENT = "vela";

// Righe CHIAVE=valore (anche con `export`, virgolette singole o doppie, commenti, CRLF); nessuna espansione di shell.
function parseEnv(text) {
    var v = {};
    String(text).split("\n").forEach(function (raw) {
        var m = /^\s*(?:export\s+)?([A-Z_][A-Z0-9_]*)=(.*?)\s*$/.exec(raw.replace(/\r$/, ""));
        if (!m) return;
        var val = m[2];
        var q = /^(["'])([\s\S]*)\1$/.exec(val);
        v[m[1]] = q ? q[2] : val;
    });
    var out = { url: (v.SUBSONIC_URL || "").replace(/\/+$/, ""), user: v.SUBSONIC_USER || "", pass: v.SUBSONIC_PASS || "", missing: [] };
    if (out.url === "") out.missing.push("SUBSONIC_URL");
    if (out.user === "") out.missing.push("SUBSONIC_USER");
    if (out.pass === "") out.missing.push("SUBSONIC_PASS");
    return out;
}

function validUrl(u) { return typeof u === "string" && /^https?:\/\/[^\s\/]+/.test(u); }

// Parametri di autenticazione: token = md5(password + salt). `md5` (stringa → esadecimale) la fornisce chi chiama.
function authQuery(user, pass, salt, md5) {
    return "u=" + encodeURIComponent(user) + "&t=" + md5(pass + salt) + "&s=" + encodeURIComponent(salt)
         + "&v=" + API_VERSION + "&c=" + CLIENT + "&f=json";
}

function albumListUrl(base, auth) { return base + "/rest/getAlbumList2.view?type=newest&size=100&" + auth; }
function albumUrl(base, id, auth) { return base + "/rest/getAlbum.view?id=" + encodeURIComponent(id) + "&" + auth; }
function streamUrl(base, id, auth) { return base + "/rest/stream.view?id=" + encodeURIComponent(id) + "&" + auth; }

function response(json) {
    var r = json && json["subsonic-response"];
    if (!r) return { ok: false, error: "risposta non valida" };
    if (r.status !== "ok") return { ok: false, error: (r.error && r.error.message) || "errore del server" };
    return { ok: true, r: r };
}

// {ok, error, albums: [{id, label}]}; due album con lo stesso nome restano distinti (si sceglie per id).
function parseAlbums(json) {
    var x = response(json);
    if (!x.ok) return { ok: false, error: x.error, albums: [] };
    var list = (x.r.albumList2 && x.r.albumList2.album) || [];
    return { ok: true, error: "", albums: list.map(function (a) { return { id: String(a.id), label: (a.artist ? a.artist + " - " : "") + a.name }; }) };
}

// {ok, error, songs: [{id, label, artist, title}]}; label = «numero. titolo», senza numero solo il titolo.
function parseSongs(json) {
    var x = response(json);
    if (!x.ok) return { ok: false, error: x.error, songs: [] };
    var list = (x.r.album && x.r.album.song) || [];
    return { ok: true, error: "", songs: list.map(function (s) {
        return { id: String(s.id), label: (s.track ? s.track + ". " : "") + s.title, artist: s.artist || "", title: s.title };
    }) };
}

// Playlist M3U: una riga di testo per voce (a capo e simili nei nomi non rompono il formato).
function playlistText(entries) {
    var out = "#EXTM3U\n";
    entries.forEach(function (e) {
        var name = (e.artist ? e.artist + " - " : "") + e.title;
        out += "#EXTINF:-1," + name.replace(/[\r\n]+/g, " ") + "\n" + e.url + "\n";
    });
    return out;
}
