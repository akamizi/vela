#!/bin/sh
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# Costruisce il pacchetto xbps di Vela senza xbps-src: compila, fa `make install` in una cartella e la impacchetta con
# xbps-create. Pensato per l'Action (dove xbps-src non può usare i namespace utente) e per chi gira già su Void.
# Le dipendenze si leggono da packaging/void/vela/template (riga `depends=`), così restano in un posto solo.
# Non applica i controlli di xbps-src (librerie condivise, strip, permessi): va bene per un repository proprio.
#
# Uso: scripts/build-xbps-direct.sh [uscita]    (default: ./build-xbps/out; servono cargo, make, xbps-create)
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-"$root/build-xbps/out"}
version=$(cat "$root/VERSION")
tpl="$root/packaging/void/vela/template"
for c in cargo make xbps-create; do command -v "$c" >/dev/null || { echo "manca $c" >&2; exit 1; }; done

deps=$(sed -n 's/^depends="\(.*\)"$/\1/p' "$tpl")
desc=$(sed -n 's/^short_desc="\(.*\)"$/\1/p' "$tpl")
[ -n "$deps" ] && [ -n "$desc" ] || { echo "template senza depends o short_desc" >&2; exit 1; }

stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
cd "$root"
make PREFIX=/usr
make install PREFIX=/usr DESTDIR="$stage"
install -Dm644 LICENSE "$stage/usr/share/licenses/vela/LICENSE"
# Script e messaggio di installazione (stessi file che xbps-src prende da srcpkgs/vela/): xbps-create li legge dalla radice
install -Dm755 packaging/void/vela/INSTALL "$stage/INSTALL"
install -Dm644 packaging/void/vela/INSTALL.msg "$stage/INSTALL.msg"

mkdir -p "$out"; cd "$out"
# glibc: il demone e l'helper sono binari Rust dinamici
xbps-create -A x86_64 -n "vela-${version}_1" -s "$desc" -D "$deps glibc" -l EUPL-1.2 \
    -H https://github.com/akamizi/vela -m "Maurizio Cavalletti <maurizio@akabit.it>" "$stage"
ls -l "$out"/vela-*.xbps
