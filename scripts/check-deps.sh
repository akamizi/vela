#!/bin/sh
# Controlla le dipendenze di Vela (sola lettura).
qml=${QML_DIR:-/usr/lib/qt6/qml}
fail=0
need() { command -v "$1" >/dev/null 2>&1 && echo "ok    $1" || { echo "MANCA $1 ($2)"; fail=1; }; }
opt()  { command -v "$1" >/dev/null 2>&1 && echo "ok    $1 (opzionale)" || echo "manca $1 (opzionale: $2)"; }
mod()  { [ -d "$qml/Quickshell/$1" ] && echo "ok    Quickshell.$1" || { echo "MANCA Quickshell.$1"; fail=1; }; }

echo "== Programmi"
need quickshell "xbps-install quickshell"
need sway "compositor"
opt  brightnessctl "luminosità"
opt  wpctl "volume (wireplumber)"
opt  nmcli "rete (NetworkManager)"
opt  bluetoothctl "bluetooth"
opt  powerprofilesctl "profilo energetico"
opt  gammastep "luce notturna"
opt  swayidle "resta sveglio"
echo "== Font"
fc-list 2>/dev/null | grep -qi "Inter" && echo "ok    Inter" || echo "manca Inter (xbps-install font-inter)"
fc-list 2>/dev/null | grep -qi "Symbols Nerd Font" && echo "ok    Symbols Nerd Font" || echo "manca Symbols Nerd Font (xbps-install nerd-fonts-symbols-ttf): senza, le icone non si vedono"
echo "== Moduli Quickshell"
for m in I3 Io Wayland Bluetooth Networking Services/Pipewire Services/UPower Services/SystemTray Services/Mpris Services/Notifications Services/Polkit; do mod "$m"; done
exit $fail
