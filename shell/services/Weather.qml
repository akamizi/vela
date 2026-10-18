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

    property string text: ""
    property string tooltip: ""
    property bool stale: false
    property var data: null

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
        [/^clearsky/, "sereno"], [/^fair/, "poco nuvoloso"], [/^partlycloudy/, "parz. nuvoloso"],
        [/^cloudy/, "nuvoloso"], [/^fog/, "nebbia"], [/thunder/, "temporale"],
        [/^rainshowers/, "rovesci"], [/^lightrain/, "pioggia debole"], [/^rain/, "pioggia"],
        [/^sleet/, "nevischio"], [/^snow/, "neve"]
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
        text = lookup(iconFor, symbol, Icons.weather.cloudy) + " " + Math.round(temp) + "°";

        var loc = Config.shell.bar.clock.locale ? Qt.locale(Config.shell.bar.clock.locale) : Qt.locale();
        var lines = [(cfg.placeName ? cfg.placeName + " — " : "") + lookup(labelFor, symbol, symbol) + ", " + temp + "°C", ""];
        if (isStale) {
            var upd = json.properties.meta && json.properties.meta.updated_at;
            var age = upd ? Math.round((now - Date.parse(upd)) / 60000) : -1;
            lines.push("⚠ dati dalla cache" + (age >= 0 ? " (" + age + " min fa)" : "") + " — rete non raggiungibile");
        }
        for (var off = 1; off <= 3; off++) {
            var day = new Date(); day.setDate(day.getDate() + off);
            var key = day.getFullYear() + "-" + day.getMonth() + "-" + day.getDate();
            var entries = series.filter(function (e) {
                var t = new Date(e.time);
                return t.getFullYear() + "-" + t.getMonth() + "-" + t.getDate() === key;
            });
            if (entries.length === 0) continue;
            var temps = entries.map(function (e) { return e.data.instant.details.air_temperature; });
            var noon = entries.reduce(function (a, b) {
                return Math.abs(new Date(b.time).getHours() - 12) < Math.abs(new Date(a.time).getHours() - 12) ? b : a;
            });
            var ds = symbolOf(noon);
            lines.push(day.toLocaleDateString(loc, "ddd") + " " + lookup(iconFor, ds, Icons.weather.cloudy) + " "
                + Math.round(Math.max.apply(null, temps)) + "°/" + Math.round(Math.min.apply(null, temps)) + "°C "
                + lookup(labelFor, ds, ds));
        }
        tooltip = lines.join("\n");
        stale = isStale;
        data = json;
    }

    function fail() {
        if (cached.loadedOnce) {
            try { render(JSON.parse(cached.text()), true); return; } catch (e) {}
        }
        text = " N/D";
        tooltip = "Errore nel recupero del meteo (yr.no)";
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
