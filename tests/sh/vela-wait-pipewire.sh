#!/bin/sh
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# `vela` (avvio) deve aspettare il socket di PipeWire: nella sessione parte insieme a session-init, che lancia PipeWire in
# background; se Quickshell si collega prima, non si ricollega più e il volume resta morto (visto il 2026-10-26).
# Prova con un quickshell e un pipewire finti e una cartella di runtime a parte: niente di quello vero viene toccato.
set -eu
here=$(cd "$(dirname "$0")" && pwd); vela="$here/../../scripts/vela"
tmp=$(mktemp -d); trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/tools" "$tmp/run" "$tmp/home"
# PATH ristretto agli strumenti che servono a `vela`: il pipewire vero del PC non deve essere visibile
for t in dirname readlink sleep id cat env; do ln -s "$(command -v $t)" "$tmp/tools/$t"; done
# quickshell finto: scrive se il socket c'era quando è partito
cat > "$tmp/bin/quickshell" <<'EOS'
#!/bin/sh
if [ -S "$XDG_RUNTIME_DIR/pipewire-0" ]; then echo "socket-presente" > "$XDG_RUNTIME_DIR/esito"; else echo "socket-assente" > "$XDG_RUNTIME_DIR/esito"; fi
EOS
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/pipewire"; chmod +x "$tmp/bin/quickshell" "$tmp/bin/pipewire"
run() { env -i HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run" PATH="$tmp/bin:$tmp/tools" "$@"; }
mksock() { python3 -c "import socket,sys,time; time.sleep($1); s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); time.sleep(5)" "$tmp/run/pipewire-0"; }
fail() { echo "FALLITO: $1" >&2; exit 1; }

# 1. il socket compare dopo 1 s: quickshell deve partire a socket presente
rm -f "$tmp/run/esito" "$tmp/run/pipewire-0"; mksock 1 & sp=$!
run "$vela"; [ "$(cat "$tmp/run/esito")" = socket-presente ] || fail "quickshell è partito prima del socket di PipeWire"
kill $sp 2>/dev/null || true; wait $sp 2>/dev/null || true

# 2. il socket non compare mai: dopo l'attesa massima (qui 3 decimi di secondo) si parte comunque
rm -f "$tmp/run/esito" "$tmp/run/pipewire-0"
run env VELA_PIPEWIRE_WAIT=3 "$vela"; [ "$(cat "$tmp/run/esito")" = socket-assente ] || fail "con PipeWire assente Vela deve partire lo stesso"

# 3. senza pipewire installato non si aspetta niente
rm -f "$tmp/run/esito" "$tmp/bin/pipewire"
start=$(date +%s); run env VELA_PIPEWIRE_WAIT=50 "$vela"; end=$(date +%s)
[ $((end - start)) -le 1 ] || fail "senza pipewire installato non deve attendere"
echo "ok vela-wait-pipewire"
