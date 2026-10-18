// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Ricerca di una città per nome (Open-Meteo Geocoding, senza chiave). La richiesta parte solo quando
// l'utente cerca una città dalle Impostazioni; il testo cercato è l'unico dato inviato.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property string query: ""
    property var results: []        // [{label, name, lat, lon}]
    property bool busy: false
    property string error: ""

    function clear() { query = ""; results = []; error = ""; }

    function search(q) {
        q = q.trim();
        if (q === "" || proc.running) return;
        query = q; results = []; error = ""; busy = true;
        // L'URL è un solo argomento (nessuna shell); il nome è codificato.
        proc.command = ["curl", "-s", "--max-time", "10",
                        "-H", "User-Agent: " + (Config.shell.weather.userAgent || "vela-shell"),
                        "https://geocoding-api.open-meteo.com/v1/search?count=6&language=it&format=json&name=" + encodeURIComponent(q)];
        proc.running = true;
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                try {
                    var j = JSON.parse(text);
                    var out = [];
                    (j.results || []).forEach(function (r) {
                        if (typeof r.latitude !== "number" || typeof r.longitude !== "number" || !r.name) return;
                        out.push({ name: r.name, lat: r.latitude, lon: r.longitude,
                                   label: r.name + (r.admin1 ? ", " + r.admin1 : "") + (r.country ? " (" + r.country + ")" : "") });
                    });
                    root.results = out;
                    if (out.length === 0) root.error = "Nessuna città trovata";
                } catch (e) {
                    root.error = "Ricerca non riuscita (rete non raggiungibile?)";
                }
            }
        }
    }
}
