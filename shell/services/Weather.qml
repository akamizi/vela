// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Meteo da api.met.no (yr.no, Locationforecast). Coordinate e User-Agent dalla configurazione
// utente: senza coordinate il servizio resta spento. Cache su disco per quando manca la rete.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/icons.js" as Icons

Singleton {
    id: root

    readonly property var cfg: Config.shell.weather
    readonly property bool enabled: typeof cfg.latitude === "number" && typeof cfg.longitude === "number"

    readonly property bool imperial: cfg.units === "imperial"
    readonly property string unitLabel: imperial ? "°F" : "°C"
    // Temperatura nell'unità scelta (l'API dà sempre °C).
    function conv(c) { return imperial ? c * 9 / 5 + 32 : c; }
    readonly property real lat: typeof cfg.latitude === "number" ? cfg.latitude : 0
    readonly property real lon: typeof cfg.longitude === "number" ? cfg.longitude : 0
    // Se cambiano città o unità (dalle Impostazioni) si aggiorna subito.
    onLatChanged: relocate.restart()
    onLonChanged: relocate.restart()
    Timer {
        id: relocate
        interval: 300      // latitudine e longitudine cambiano insieme: una sola richiesta
        onTriggered: { if (!root.enabled) return; fetch.running = false; root.data = null; root.refresh(); }
    }
    onImperialChanged: if (data) render(data, stale)

    property string text: ""
    property int ageMinutes: -1
    property bool stale: false
    property var data: null
    // Dati per il pannello (D-035): condizioni attuali, una voce ogni 3 ore per 24 ore, 5 giorni.
    property var current: null
    property var hours: []
    property var days: []
    readonly property string windUnit: imperial ? "mph" : "km/h"
    function iconOf(symbol) { return lookup(iconFor, symbol, Icons.weather.cloudy); }
    function labelOf(symbol) { return lookup(labelFor, symbol, symbol); }
    function windOf(ms) { return imperial ? ms * 2.23694 : ms * 3.6; }
    function precipOf(entry) {
        var d = entry.data, p = d.next_1_hours || d.next_6_hours;
        return p && p.details && typeof p.details.precipitation_amount === "number" ? p.details.precipitation_amount : 0;
    }

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/vela"
    readonly property string cachePath: cacheDir + "/weather.json"

    readonly property var iconFor: [
        [/^clearsky.*night/, Icons.weather.night], [/^clearsky/, Icons.weather.sunny],
        [/^(fair|partlycloudy)/, Icons.weather.partly], [/^cloudy/, Icons.weather.cloudy],
        [/^fog/, Icons.weather.fog], [/thunder/, Icons.weather.lightning],
        [/^(lightrain|rainshowers)/, Icons.weather.pouring], [/^rain/, Icons.weather.rainy],
        [/^sleet/, Icons.weather.snowyRainy], [/^(lightsnow|snowshowers|snow)/, Icons.weather.snowy]
    ]
    readonly property var labelFor: [
        [/^clearsky/, I18n.tr("sereno")], [/^fair/, I18n.tr("poco nuvoloso")], [/^partlycloudy/, I18n.tr("parz. nuvoloso")],
        [/^cloudy/, I18n.tr("nuvoloso")], [/^fog/, I18n.tr("nebbia")], [/thunder/, I18n.tr("temporale")],
        [/^rainshowers/, I18n.tr("rovesci")], [/^lightrain/, I18n.tr("pioggia debole")], [/^rain/, I18n.tr("pioggia")],
        [/^sleet/, I18n.tr("nevischio")], [/^snow/, I18n.tr("neve")]
    ]

    function lookup(table, symbol, fallback) {
        for (var i = 0; i < table.length; i++) if (table[i][0].test(symbol)) return table[i][1];
        return fallback;
    }

    function symbolOf(entry) {
        var d = entry.data;
        var s = (d.next_1_hours || d.next_6_hours || d.next_12_hours);
        return s ? s.summary.symbol_code : "cloudy";
    }

    function render(json, isStale) {
        var series = json.properties.timeseries;
        var now = Date.now();
        var best = series[0];
        for (var i = 1; i < series.length; i++)
            if (Math.abs(Date.parse(series[i].time) - now) < Math.abs(Date.parse(best.time) - now)) best = series[i];
        var temp = best.data.instant.details.air_temperature;
        var symbol = symbolOf(best);
        text = lookup(iconFor, symbol, Icons.weather.cloudy) + " " + Math.round(conv(temp)) + "°";

        // Età dei dati quando arrivano dalla cache (la mostra il pannello).
        var upd = json.properties.meta && json.properties.meta.updated_at;
        ageMinutes = isStale && upd ? Math.round((now - Date.parse(upd)) / 60000) : -1;

        var inst = best.data.instant.details;
        current = { temp: conv(temp), icon: lookup(iconFor, symbol, Icons.weather.cloudy), label: lookup(labelFor, symbol, symbol),
                    wind: windOf(inst.wind_speed || 0), humidity: inst.relative_humidity, pressure: inst.air_pressure_at_sea_level };

        // Una voce ogni 3 ore a partire da adesso.
        var start = 0;
        for (var s0 = 0; s0 < series.length; s0++) if (Date.parse(series[s0].time) >= now - 1800000) { start = s0; break; }
        var t0 = Date.parse(series[start].time), hs = [];
        for (var k = 0; k < 8; k++) {
            var target = t0 + k * 3 * 3600000, pick = null;
            for (var q = start; q < series.length; q++) {
                var dt = Math.abs(Date.parse(series[q].time) - target);
                if (pick === null || dt < pick.dt) pick = { e: series[q], dt: dt }; else if (dt > pick.dt) break;
            }
            if (pick === null || pick.dt > 3600000) break;
            hs.push({ time: pick.e.time, temp: conv(pick.e.data.instant.details.air_temperature), icon: lookup(iconFor, symbolOf(pick.e), Icons.weather.cloudy), precip: precipOf(pick.e) });
        }
        hours = hs;

        // Oggi (la parte che resta) e i quattro giorni dopo.
        var ds = [];
        for (var o = 0; o < 5; o++) {
            var dd = new Date(); dd.setDate(dd.getDate() + o);
            var dk = dd.getFullYear() + "-" + dd.getMonth() + "-" + dd.getDate();
            var es = series.filter(function (e) { var t = new Date(e.time); return t.getFullYear() + "-" + t.getMonth() + "-" + t.getDate() === dk; });
            if (es.length === 0) continue;
            var tt = es.map(function (e) { return e.data.instant.details.air_temperature; });
            var mid = es.reduce(function (a, b) { return Math.abs(new Date(b.time).getHours() - 13) < Math.abs(new Date(a.time).getHours() - 13) ? b : a; });
            var sym = symbolOf(mid);
            ds.push({ date: dd, max: conv(Math.max.apply(null, tt)), min: conv(Math.min.apply(null, tt)), icon: lookup(iconFor, sym, Icons.weather.cloudy),
                      label: lookup(labelFor, sym, sym), precip: es.reduce(function (a, e) { return a + precipOf(e); }, 0) });
        }
        days = ds;
        stale = isStale;
        data = json;
    }

    function fail() {
        if (cached.loadedOnce) {
            try { render(JSON.parse(cached.text()), true); return; } catch (e) {}
        }
        text = " N/D";
    }

    FileView { id: cached; path: root.cachePath; blockLoading: true; printErrors: false
        property bool loadedOnce: false
        onLoaded: loadedOnce = true }
    Process { id: mkdir; command: ["mkdir", "-p", root.cacheDir] }

    Process {
        id: fetch
        command: ["curl", "-s", "--max-time", "10", "--retry", "4", "--retry-delay", "3",
                  "--retry-connrefused", "--retry-all-errors",
                  "-H", "User-Agent: " + root.cfg.userAgent,
                  "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=" + root.cfg.latitude + "&lon=" + root.cfg.longitude]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text);
                    if (!j.properties || !j.properties.timeseries) throw new Error("risposta senza timeseries");
                    root.render(j, false);
                    cached.setText(text);
                } catch (e) {
                    root.fail();
                }
            }
        }
    }

    function refresh() {
        if (!enabled || fetch.running) return;
        fetch.running = true;
    }

    Component.onCompleted: { if (enabled) { mkdir.running = true; cached.reload(); refresh(); } }
    Timer { interval: Config.shell.weather.interval * 1000; running: root.enabled; repeat: true; onTriggered: root.refresh() }
}
