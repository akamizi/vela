// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Un file di configurazione a strati: default (repository) + override utente.
// Un override illeggibile o malformato non fa cadere la shell: si usa il default
// e si riempie `warnings`.
import QtQuick
import Quickshell.Io
import "jsonc.js" as Jsonc

QtObject {
    id: root

    required property string name        // "theme" -> theme.jsonc
    required property string defaultsDir
    required property string userDir
    property string mode: "object"      // "menu" = merge per id delle voci

    property var data: ({})
    property var warnings: []

    property FileView defaultFile: FileView {
        path: root.defaultsDir + "/" + root.name + ".jsonc"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.rebuild()
    }

    property FileView userFile: FileView {
        path: root.userDir + "/" + root.name + ".jsonc"
        printErrors: false   // l'override è facoltativo: file assente = nessun errore
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rebuild()
        onLoadFailed: root.rebuild()   // file assente: nessun override
    }

    function readText(file) {
        try { return file.text(); } catch (e) { return ""; }
    }

    function rebuild() {
        var w = [];
        var base = {};
        try {
            base = Jsonc.parse(readText(defaultFile));
        } catch (e) {
            // I default fanno parte del codice: se sono rotti è un bug, non un errore utente.
            w.push(name + ".jsonc (default): " + e.message);
        }

        var result = base;
        var userText = readText(userFile);
        if (userText.trim() !== "") {
            try {
                var typeWarnings = [];
                var over = Jsonc.parse(userText);
                result = mode === "menu" ? Jsonc.mergeMenu(base, over, "", typeWarnings)
                                         : Jsonc.merge(base, over, "", typeWarnings);
                for (var i = 0; i < typeWarnings.length; i++)
                    w.push(name + ".jsonc: " + typeWarnings[i]);
            } catch (e) {
                w.push(name + ".jsonc (utente): " + e.message);
            }
        }
        data = result;
        // Il rebuild parte da più segnali all'avvio: si logga solo se gli avvisi cambiano.
        if (w.join("|") !== warnings.join("|") && w.length > 0)
            console.warn("[vela] " + w.join(" | "));
        warnings = w;
    }

    Component.onCompleted: rebuild()
}
