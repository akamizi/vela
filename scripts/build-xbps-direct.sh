#!/bin/sh
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# Costruisce il pacchetto xbps di Vela senza xbps-src: compila, fa `make install` in una cartella e la impacchetta con
# xbps-create (e anche il meta-pacchetto vela-recommended). Pensato per l'Action (dove xbps-src non può usare i namespace utente) e per chi gira già su Void.
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

# xbps-create non completa i nomi nudi come fa xbps-src: una dipendenza senza versione, se il pacchetto non è installato,
# fa fallire xbps-install ("can't guess pkgname for dependency"). Si aggiunge `>=0` ai nomi senza operatore.
versioned() { for d in $1; do case $d in *[\<\>=]*) printf '%s ' "$d" ;; *) printf '%s>=0 ' "$d" ;; esac; done; }

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
xbps-create -A x86_64 -n "vela-${version}_1" -s "$desc" -D "$(versioned "$deps glibc")" -l EUPL-1.2 \
    -H https://github.com/akamizi/vela -m "Maurizio Cavalletti <maurizio@akabit.it>" "$stage"

# Meta-pacchetto vela-recommended: nessun file, solo le dipendenze del suo template (versione = quella di Vela)
rtpl="$root/packaging/void/vela-recommended/template"
rdeps=$(awk '/^depends="/{f=1} f{print} f&&/"$/{exit}' "$rtpl" | tr '\n' ' ' | sed 's/^depends="//; s/" *$//' | sed "s/\${version}/${version}/g")
rdesc=$(sed -n 's/^short_desc="\(.*\)"$/\1/p' "$rtpl")
[ -n "$rdeps" ] && [ -n "$rdesc" ] || { echo "template di vela-recommended senza depends o short_desc" >&2; exit 1; }
meta=$(mktemp -d); trap 'rm -rf "$stage" "$meta"' EXIT
xbps-create -A noarch -n "vela-recommended-${version}_1" -s "$rdesc" -D "$(versioned "$rdeps")" -l EUPL-1.2 \
    -H https://github.com/akamizi/vela -m "Maurizio Cavalletti <maurizio@akabit.it>" "$meta"
ls -l "$out"/vela-*.xbps
