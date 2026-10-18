// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Lettura e modifica delle impostazioni scritte dal pannello (strato settings.jsonc, D-021).
// `file` è "shell" o "theme"; `path` è un percorso con punti, es. "bar.position".
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    function parts(path) { return path.split("."); }

    // Valore effettivo (default + override utente + impostazioni).
    function get(file, path) {
        var o = Config[file], p = parts(path);
        for (var i = 0; i < p.length && o !== undefined && o !== null; i++) o = o[p[i]];
        return o;
    }

    // true se il pannello ha impostato questa chiave (e quindi "ripristina" ha qualcosa da togliere).
    function overridden(file, path) {
        var o = Config.settingsData[file], p = parts(path);
        for (var i = 0; i < p.length; i++) {
            if (o === undefined || o === null || typeof o !== "object" || !(p[i] in o)) return false;
            o = o[p[i]];
        }
        return true;
    }

    function edit(mutator) {
        var d = JSON.parse(JSON.stringify(Config.settingsData));
        mutator(d);
        Config.writeSettings(d);
    }

    function put(d, file, path, value) {
        if (typeof d[file] !== "object" || d[file] === null) d[file] = {};
        var o = d[file], p = parts(path);
        for (var i = 0; i < p.length - 1; i++) {
            if (typeof o[p[i]] !== "object" || o[p[i]] === null || Array.isArray(o[p[i]])) o[p[i]] = {};
            o = o[p[i]];
        }
        o[p[p.length - 1]] = value;
    }

    // Toglie la chiave e i contenitori rimasti vuoti.
    function drop(d, file, path) {
        var chain = [d], p = [file].concat(parts(path));
        var o = d;
        for (var i = 0; i < p.length - 1; i++) {
            if (typeof o[p[i]] !== "object" || o[p[i]] === null) return;
            o = o[p[i]];
            chain.push(o);
        }
        delete o[p[p.length - 1]];
        for (var j = chain.length - 1; j > 0; j--)
            if (Object.keys(chain[j]).length === 0) delete chain[j - 1][p[j - 1]];
    }

    function set(file, path, value) { edit(function (d) { put(d, file, path, value); }); }
    function setMany(file, map) { edit(function (d) { for (var k in map) put(d, file, k, map[k]); }); }
    function reset(file, path) { edit(function (d) { drop(d, file, path); }); }
    // list: [["theme", "colors"], ["shell", "bar.position"], ...]
    function resetMany(list) { edit(function (d) { list.forEach(function (e) { drop(d, e[0], e[1]); }); }); }
}
