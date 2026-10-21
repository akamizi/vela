// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Stampanti (D-046): stato di CUPS letto con gli strumenti da riga di comando (lpstat), azioni con lpoptions, cupsenable/cupsdisable e cancel.
// Il pannello si interroga solo da aperto: nessun processo periodico a pannello chiuso. Le operazioni di amministrazione (pausa,
// ripresa) passano da CUPS, che autorizza per gruppo (`lpadmin`): Vela non vede né custodisce password.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool known: false            // almeno una lettura completata
    property bool schedulerUp: false      // cupsd risponde
    property var printers: []             // [{name, state: "idle"|"printing"|"disabled", reason}]
    property var jobs: []                 // [{id, printer, user, size}]
    property string defaultName: ""
    property bool admin: false            // l'utente è nel gruppo lpadmin (o root)
    property string error: ""             // ultimo errore di un'azione, da mostrare nel pannello
    property var devices: []              // dispositivi trovati dalla ricerca: [{uri, info, make}]
    property bool scanning: false
    property bool scanned: false          // almeno una ricerca completata

    // Nomi di stampante e id di lavoro finiscono come argomenti (mai in una shell), ma si accettano solo caratteri attesi.
    function validName(n) { return typeof n === "string" && /^[A-Za-z0-9_.\-]+$/.test(n); }

    // Lettura in lingua C: i messaggi di lpstat sono tradotti e non si possono interpretare altrimenti.
    function parse(text) {
        var sec = "", up = false, def = "", prs = [], js = [], adm = false, uriOf = {};
        text.split("\n").forEach(function (line) {
            if (line.charAt(0) === "@") { sec = line.slice(1).trim(); return; }
            if (sec === "sched") { up = line.indexOf("up") === 0; return; }
            if (sec === "default") {
                var m = line.match(/^system default destination: (\S+)/);
                if (m) def = m[1];
            } else if (sec === "printers") {
                var p = line.match(/^printer (\S+) (.*)$/);
                if (p) {
                    var rest = p[2], st = "idle";
                    if (rest.indexOf("disabled") === 0) st = "disabled";
                    else if (rest.indexOf("now printing") === 0) st = "printing";
                    prs.push({ name: p[1], state: st, reason: "" });
                } else if (/^\s+\S/.test(line) && prs.length > 0 && prs[prs.length - 1].reason === "") {
                    prs[prs.length - 1].reason = line.trim();
                }
            } else if (sec === "jobs") {
                var f = line.trim().split(/\s+/);
                var j = f[0] ? f[0].match(/^(.+)-(\d+)$/) : null;
                if (j && f.length >= 3) js.push({ id: f[0], printer: j[1], user: f[1], size: Number(f[2]) || 0 });
            } else if (sec === "uris") {
                var u = line.match(/^device for (\S+): (\S+)/);
                if (u) uriOf[u[1]] = u[2];
            } else if (sec === "groups") {
                line.trim().split(/\s+/).forEach(function (g) { if (g === "lpadmin") adm = true; });
            } else if (sec === "uid") {
                if (line.trim() === "0") adm = true;
            }
        });
        prs.forEach(function (p) { p.uri = uriOf[p.name] || ""; });
        schedulerUp = up;
        printers = prs;
        jobs = js;
        defaultName = def;
        admin = adm;
        known = true;
    }

    Process {
        id: poll
        command: ["timeout", "6", "sh", "-c",
            "export LC_ALL=C; echo @sched; if lpstat -r 2>/dev/null | grep -q 'is running'; then echo up; else echo down; exit 0; fi;"
            + " echo @default; lpstat -d 2>/dev/null; echo @printers; lpstat -p 2>/dev/null; echo @jobs; lpstat -o 2>/dev/null;"
            + " echo @uris; lpstat -v 2>/dev/null; echo @groups; id -nG; echo @uid; id -u"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    function refresh() { if (!poll.running) poll.running = true; }

    // Azioni: `command` è un array di argomenti; l'errore (stderr) si mostra nel pannello, poi si rilegge lo stato.
    property var pendingAction: null
    Process {
        id: actor
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            root.error = code === 0 ? "" : (actErr.text.trim().split("\n")[0] || "errore");
            root.refresh();
        }
    }
    function act(command) {
        if (actor.running) return;
        error = "";
        actor.command = ["env", "LC_ALL=C"].concat(command);
        actor.running = true;
    }

    function setDefault(name) { if (validName(name)) act(["lpoptions", "-d", name]); }
    function togglePause(name, state) {
        if (!validName(name)) return;
        if (!admin) { error = I18n.tr("Per fermare o riprendere una stampante serve il gruppo lpadmin"); return; }
        act([state === "disabled" ? "cupsenable" : "cupsdisable", name]);
    }
    function cancelJob(id) { if (validName(id)) act(["cancel", id]); }
    function cancelAll(name) { if (validName(name)) act(["cancel", "-a", name]); }

    // --- aggiunta e rimozione (D-046, passo 2) ---------------------------------------------------------
    // Ricerca dei dispositivi con `lpinfo -l -v` (blocchi "Device: uri = …" seguiti da "chiave = valore"): si tengono solo quelli con un
    // indirizzo vero (non i nomi di protocollo nudi) e non ancora configurati.
    function parseDevices(text) {
        var out = [], cur = null;
        text.split("\n").forEach(function (line) {
            var d = line.match(/^Device: uri = (\S+)/);
            if (d) { cur = { uri: d[1], info: "", make: "" }; out.push(cur); return; }
            var kv = line.match(/^\s+(info|make-and-model) = (.*)$/);
            if (kv && cur) { if (kv[1] === "info") cur.info = kv[2]; else cur.make = kv[2]; }
        });
        var known = printers.map(function (p) { return p.uri; });
        devices = out.filter(function (d) { return validUri(d.uri) && d.uri.indexOf("cups-pdf") !== 0 && known.indexOf(d.uri) < 0; });
        scanned = true;
    }
    Process {
        id: scanner
        command: ["timeout", "25", "env", "LC_ALL=C", "lpinfo", "-l", "-v"]
        stdout: StdioCollector { onStreamFinished: root.parseDevices(text) }
        onExited: root.scanning = false
    }
    function scan() { if (scanner.running) return; devices = []; scanning = true; scanner.running = true; }

    function validUri(u) { return typeof u === "string" && /^[a-z][a-z0-9+.\-]*:\/\/[^\s]+$/.test(u); }
    // Indirizzo digitato: un URI completo, oppure un nome/IP che diventa ipp://<host>/ipp/print
    function normalizeAddress(text) {
        var t = (text || "").trim();
        if (validUri(t)) return t;
        if (/^[A-Za-z0-9.\-]+(:\d+)?$/.test(t)) return "ipp://" + t + "/ipp/print";
        return "";
    }
    // Nome di coda valido e libero, ricavato dalla descrizione o dal nome dell'host.
    function suggestName(uri, info) {
        var base = (info || "").replace(/[^A-Za-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 24);
        if (base === "") { var h = uri.match(/^[a-z][a-z0-9+.\-]*:\/\/(?:[^@\/]*@)?([^:\/?]+)/); base = h ? h[1].replace(/[^A-Za-z0-9]+/g, "_") : "Stampante"; }
        var name = base, n = 2, taken = printers.map(function (p) { return p.name; });
        while (taken.indexOf(name) >= 0) name = base + "_" + (n++);
        return name;
    }
    function addPrinter(uri, info) {
        if (!validUri(uri)) { error = I18n.tr("Indirizzo non valido"); return; }
        if (!admin) { error = I18n.tr("Per aggiungere una stampante serve il gruppo lpadmin"); return; }
        act(["lpadmin", "-p", suggestName(uri, info), "-E", "-v", uri, "-m", "everywhere"]);
    }
    function removePrinter(name) {
        if (!validName(name)) return;
        if (!admin) { error = I18n.tr("Per rimuovere una stampante serve il gruppo lpadmin"); return; }
        act(["lpadmin", "-x", name]);
    }
}
