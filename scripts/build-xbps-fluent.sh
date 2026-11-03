#!/bin/sh
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# Costruisce il pacchetto xbps del tema icone Fluent (D-061) senza xbps-src, con xbps-create: scarica i sorgenti upstream,
# ne verifica il checksum, esegue install.sh in una cartella e la impacchetta. Versione, checksum, varianti e licenza si
# leggono da packaging/void/fluent-icon-theme/template, così restano in un posto solo. Chiamato da build-xbps-direct.sh.
#
# Uso: scripts/build-xbps-fluent.sh [uscita]    (default: ./build-xbps/out; servono bash, curl, sha256sum, tar, xbps-create)
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-"$root/build-xbps/out"}
tpl="$root/packaging/void/fluent-icon-theme/template"
for c in bash curl sha256sum tar xbps-create; do command -v "$c" >/dev/null || { echo "manca $c" >&2; exit 1; }; done

val() { sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\1/p" "$tpl" | head -n 1; }
version=$(val version); sum=$(val checksum); variants=$(val _variants)
desc=$(val short_desc); license=$(val license); deps=$(val depends)
[ -n "$version" ] && [ -n "$sum" ] && [ -n "$variants" ] && [ -n "$desc" ] && [ -n "$license" ] \
    || { echo "template di fluent-icon-theme incompleto" >&2; exit 1; }
# Il tag upstream è la data con i trattini: 20260727 -> 2026-07-27
tag="$(printf %s "$version" | cut -c1-4)-$(printf %s "$version" | cut -c5-6)-$(printf %s "$version" | cut -c7-8)"
url="https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/tags/${tag}.tar.gz"

work=$(mktemp -d); stage=$(mktemp -d); trap 'rm -rf "$work" "$stage"' EXIT
curl -fsSL -o "$work/src.tar.gz" "$url"
echo "$sum  $work/src.tar.gz" | sha256sum -c - >/dev/null || { echo "checksum di $url diverso da quello del template" >&2; exit 1; }
tar -C "$work" -xzf "$work/src.tar.gz"
src="$work/Fluent-icon-theme-${tag}"
[ -f "$src/install.sh" ] || { echo "install.sh non trovato in $src" >&2; exit 1; }

mkdir -p "$stage/usr/share/icons" "$stage/usr/share/doc/fluent-icon-theme" "$stage/usr/share/licenses/fluent-icon-theme"
# install.sh vuole una destinazione esplicita: senza -d usa la home di chi compila
( cd "$src" && bash install.sh -d "$stage/usr/share/icons" $variants >/dev/null )
install -m644 "$src/AUTHORS" "$stage/usr/share/doc/fluent-icon-theme/AUTHORS"
install -m644 "$src/COPYING" "$stage/usr/share/licenses/fluent-icon-theme/COPYING"

versioned() { for d in $1; do case $d in *[\<\>=]*) printf '%s ' "$d" ;; *) printf '%s>=0 ' "$d" ;; esac; done; }
mkdir -p "$out"; cd "$out"
xbps-create -A noarch -n "fluent-icon-theme-${version}_1" -s "$desc" -D "$(versioned "$deps")" -l "$license" \
    -H https://github.com/vinceliuice/Fluent-icon-theme -m "Maurizio Cavalletti <maurizio@akabit.it>" "$stage"
ls -l "$out"/fluent-icon-theme-*.xbps
