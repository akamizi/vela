// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Applicazioni installate (voci .desktop) con ricerca fuzzy.
pragma Singleton
import QtQuick
import Quickshell
import "../core"
import "../core/fuzzy.js" as Fuzzy

Singleton {
    id: root

    readonly property var all: {
        var list = DesktopEntries.applications.values.filter(function (e) { return !e.noDisplay; });
        list.sort(function (a, b) { return a.name.localeCompare(b.name); });
        return list;
    }

    function row(entry, score) {
        return { kind: "app", label: entry.name, sub: entry.comment || entry.genericName || "",
                 icon: entry.icon, entry: entry, score: score };
    }

    // Senza testo: tutte in ordine alfabetico. Con testo: le migliori `limit`.
    function search(query, limit) {
        if (query === "") return all.slice(0, limit).map(function (e) { return row(e, 0); });
        var hits = [];
        for (var i = 0; i < all.length; i++) {
            var e = all[i];
            var s = Fuzzy.score(query, e.name);
            // descrizione e parole chiave: solo corrispondenza esatta di una parte del testo
            var extra = Fuzzy.norm(e.genericName + " " + e.keywords);
            if (extra.indexOf(Fuzzy.norm(query)) >= 0 && s < 1) s = 1;
            if (s >= 0) hits.push(row(e, s));
        }
        hits.sort(function (a, b) { return b.score - a.score; });
        return hits.slice(0, limit);
    }

    function launch(entry) { entry.execute(); }

    // Percorso dell'icona nel tema in uso; stringa vuota se non si trova.
    function iconSource(name) {
        if (!name) return "";
        return name.charAt(0) === "/" ? "file://" + name : Quickshell.iconPath(name, true);
    }
}
