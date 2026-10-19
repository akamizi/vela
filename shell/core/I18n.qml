// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Traduzioni (D-028). Il testo italiano è anche la chiave: I18n.tr("Rete") restituisce "Network" con il catalogo
// inglese e "Rete" se la voce manca (o se la lingua è l'italiano). I segnaposto sono %1, %2…:
// I18n.tr("Comando per %1", combo). Cataloghi: i18n/<lingua>.json del pacchetto, poi ~/.config/vela/i18n/<lingua>.json.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "language" in configurazione; vuoto = lingua dell'ambiente (LC_ALL, LC_MESSAGES, LANG), poi italiano.
    readonly property string lang: {
        var c = Config.shell.language;
        if (typeof c === "string" && c !== "") return c.toLowerCase().slice(0, 2);
        var e = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        var m = /^([a-z]{2})/i.exec(e);
        return m && e !== "C" && e !== "POSIX" ? m[1].toLowerCase() : "it";
    }

    property var packaged: ({})
    property var custom: ({})
    // Italiano = nessun catalogo: i testi del codice sono già in italiano.
    readonly property var catalog: lang === "it" ? ({}) : Object.assign({}, packaged, custom)

    function tr(text) {
        var out = catalog[text];
        if (out === undefined || out === "") out = text;
        for (var i = 1; i < arguments.length; i++) out = out.split("%" + i).join(String(arguments[i]));
        return out;
    }

    function parse(t) {
        try { var d = JSON.parse(t); return d && typeof d === "object" ? d : ({}); }
        catch (e) { return ({}); }
    }

    FileView {
        path: Quickshell.shellDir + "/../i18n/" + root.lang + ".json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.packaged = root.parse(text())
        onLoadFailed: root.packaged = ({})
    }
    FileView {
        path: Config.userDir + "/i18n/" + root.lang + ".json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.custom = root.parse(text())
        onLoadFailed: root.custom = ({})
    }
}
