// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// CPU, memoria, temperatura e ventola da /proc e sysfs. Sensori rilevati a runtime:
// se non esistono (nessuna ventola, ecc.) le relative proprietà restano "non disponibili".
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property real cpu: 0                 // %
    property real memUsedGb: 0
    property real temperature: NaN       // °C
    property real fanRpm: NaN
    readonly property bool hasTemperature: !isNaN(temperature)
    readonly property bool hasFan: !isNaN(fanRpm)

    property string tempPath: ""
    property string fanPath: ""
    property var lastCpu: null

    // Rilevamento sensori: script fisso, il nome del sensore preferito arriva come argomento.
    Process {
        id: discover
        command: ["sh", "-c", [
            'pt=""; pf=""',
            'for d in /sys/class/hwmon/hwmon*; do',
            '  n=$(cat "$d/name" 2>/dev/null)',
            '  if [ -r "$d/temp1_input" ]; then',
            '    if [ -n "$1" ] && [ "$n" = "$1" ]; then pt=$d/temp1_input',
            '    elif [ -z "$pt" ]; then case "$n" in coretemp|k10temp|zenpower) pt=$d/temp1_input;; esac; fi',
            '  fi',
            '  if [ -r "$d/fan1_input" ]; then',
            '    if [ "$n" != acpi_fan ]; then pf=$d/fan1_input; elif [ -z "$pf" ]; then pf=$d/fan1_input; fi',
            '  fi',
            'done',
            'echo "temp=$pt"; echo "fan=$pf"'
        ].join("\n"), "sh", Config.shell.stats.temperatureSensor]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("temp=") === 0) root.tempPath = lines[i].slice(5);
                    if (lines[i].indexOf("fan=") === 0) root.fanPath = lines[i].slice(4);
                }
                root.poll();
            }
        }
    }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
    FileView { id: tempFile; path: root.tempPath; blockLoading: true; printErrors: false }
    FileView { id: fanFile; path: root.fanPath; blockLoading: true; printErrors: false }

    function poll() {
        statFile.reload();
        var f = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length >= 5) {
            var idle = f[3] + f[4];
            var total = f.reduce(function (a, b) { return a + b; }, 0);
            if (lastCpu && total > lastCpu.total)
                cpu = Math.round(100 * (1 - (idle - lastCpu.idle) / (total - lastCpu.total)));
            lastCpu = { idle: idle, total: total };
        }

        memFile.reload();
        var m = memFile.text();
        var tot = /MemTotal:\s+(\d+)/.exec(m), avail = /MemAvailable:\s+(\d+)/.exec(m);
        if (tot && avail) memUsedGb = (Number(tot[1]) - Number(avail[1])) / 1048576;

        if (tempPath !== "") {
            tempFile.reload();
            var t = Number(tempFile.text().trim());
            temperature = isNaN(t) ? NaN : Math.round(t / 1000);
        }
        if (fanPath !== "") {
            fanFile.reload();
            var r = Number(fanFile.text().trim());
            fanRpm = isNaN(r) ? NaN : r;
        }
    }

    Timer {
        interval: Config.shell.stats.interval * 1000
        running: true
        repeat: true
        onTriggered: root.poll()
    }
}
