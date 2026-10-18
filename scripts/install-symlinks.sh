#!/bin/sh
# Installazione di sviluppo: crea ~/.local/bin/vela -> scripts/vela.
# Se esiste già qualcosa lo sposta in .bak-vela. Uso: install-symlinks.sh [--dry-run]
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
src=$(readlink -f "$(dirname "$0")/vela")
dst="$HOME/.local/bin/vela"

run() { if [ $dry = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

[ -d "$HOME/.local/bin" ] || run mkdir -p "$HOME/.local/bin"
if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$src" ]; then
    echo "già installato: $dst -> $src"; exit 0
fi
if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "backup: $dst -> $dst.bak-vela"
    run mv "$dst" "$dst.bak-vela"
fi
echo "symlink: $dst -> $src"
run ln -s "$src" "$dst"
