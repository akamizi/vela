// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Icone Nerd Font (Material Design Icons, area privata Unicode), con punti di codice espliciti.
.pragma library

function cp(n) { return String.fromCodePoint(n); }

var menu = cp(0xF035C);
var trayCollapsed = cp(0xF0141), trayExpanded = cp(0xF0142);
var bluetooth = cp(0xF00AF), bluetoothOff = cp(0xF00B2), bluetoothConnected = cp(0xF00B1);
var ethernet = cp(0xF0200), wifiOff = cp(0xF092E);
var wifi = [cp(0xF092F), cp(0xF091F), cp(0xF0922), cp(0xF0925), cp(0xF0928)];
var mic = cp(0xF036C), micOff = cp(0xF036D);
var volumeMuted = cp(0xF075F);
var volume = [cp(0xF057F), cp(0xF0580), cp(0xF057E)];
var brightness = [cp(0xF00DE), cp(0xF00DF), cp(0xF00E0)];
var powerSaver = cp(0xF0F86), balanced = cp(0xF0F85), performance = cp(0xF04C5);
var battery = [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F,
               0xF0080, 0xF0081, 0xF0082, 0xF0079].map(cp);
var batteryCharging = [0xF089F, 0xF089C, 0xF0086, 0xF0087, 0xF0088, 0xF089D,
                       0xF0089, 0xF089E, 0xF008A, 0xF008B, 0xF0085].map(cp);
var plug = cp(0xF1E6);
var memory = cp(0xE266), cpu = cp(0xF2DB), fan = cp(0xF0210);
var thermometer = [cp(0xF2CB), cp(0xF2C9), cp(0xF2C7)];
var dnd = cp(0xF009B), night = cp(0xF0594), awake = cp(0xF0176);
var recording = cp(0xF044A);
var play = cp(0x25B6), pause = cp(0x23F8);
var vpn = cp(0xF0582);
var keyboard = cp(0xF030C);
var lock = cp(0xF033E), check = cp(0xF012C), power = cp(0xF0425);

// Meteo (simbolo yr.no -> icona)
var weather = {
    sunny: cp(0xF0599), night: cp(0xF0594), partly: cp(0xF0595), cloudy: cp(0xF0590),
    fog: cp(0xF0591), lightning: cp(0xF0593), pouring: cp(0xF0596), rainy: cp(0xF0597),
    snowyRainy: cp(0xF067F), snowy: cp(0xF0598)
};

// Sceglie l'icona di una lista in base a una frazione 0..1.
function pick(list, fraction) {
    var f = fraction >= 0 ? Math.min(1, fraction) : 0;   // NaN e negativi -> 0
    return list[Math.min(list.length - 1, Math.floor(f * list.length))];
}
