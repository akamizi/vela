// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Cartella Musica e file audio: logica pura del pannello Musica (nessuno shell, solo stringhe).
.pragma library
.import "userdirs.js" as UserDirs

var extensions = ["mp3", "flac", "ogg", "m4a", "wav", "opus"];

// Cartelle da provare, in ordine: quella di XDG_MUSIC_DIR (in qualunque lingua), poi ~/Musica e ~/Music.
function musicDirCandidates(userDirsText, home) {
    var out = [];
    [UserDirs.userDir(userDirsText, home, "XDG_MUSIC_DIR"), home + "/Musica", home + "/Music"].forEach(function (d) {
        if (d !== "" && out.indexOf(d) < 0) out.push(d);
    });
    return out;
}

function isAudio(name) {
    var m = /\.([^.\/]+)$/.exec(String(name));
    return m !== null && extensions.indexOf(m[1].toLowerCase()) >= 0;
}

function cmp(a, b) {
    var x = a.toLowerCase(), y = b.toLowerCase();
    return x < y ? -1 : x > y ? 1 : (a < b ? -1 : a > b ? 1 : 0);
}

// Dai percorsi dei file (sotto `root`) alle cartelle che contengono audio:
// [{rel, path, files: [{name, path}]}], ordinate per `rel` senza distinzione di maiuscole; `rel` è "" per la radice.
function groupFolders(paths, root) {
    var by = {};
    paths.forEach(function (p) {
        if (!isAudio(p)) return;
        var i = p.lastIndexOf("/");
        var dir = p.slice(0, i), name = p.slice(i + 1);
        (by[dir] = by[dir] || []).push({ name: name, path: p });
    });
    return Object.keys(by).map(function (dir) {
        var rel = dir === root ? "" : dir.indexOf(root + "/") === 0 ? dir.slice(root.length + 1) : dir;
        var files = by[dir].sort(function (a, b) { return cmp(a.name, b.name); });
        return { rel: rel, path: dir, files: files };
    }).sort(function (a, b) { return cmp(a.rel, b.rel); });
}
