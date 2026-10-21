#!/bin/sh
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# Costruisce il pacchetto xbps di Vela con xbps-src (void-packages) e lo lascia in <uscita>.
#
# Uso: scripts/build-xbps.sh [versione] [cartella-di-lavoro] [cartella-di-uscita]
#   versione            default: contenuto del file VERSION (deve esistere il tag v<versione> su GitHub)
#   cartella-di-lavoro  default: ./build-xbps/work   (vi si clona void-packages)
#   cartella-di-uscita  default: ./build-xbps/out    (vi si copiano i .xbps)
#
# Va eseguito da utente normale (xbps-src rifiuta root), non usa sudo. Servono git, curl, sha256sum e i
# permessi di xbps-src (user namespace). Il checksum del tarball si calcola qui: nel template resta quello
# dell'ultima release pubblicata a mano, che per un tag nuovo sarebbe sbagliato.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=${1:-$(cat "$root/VERSION")}
work=${2:-"$root/build-xbps/work"}
out=${3:-"$root/build-xbps/out"}
url="https://github.com/akamizi/vela/archive/v${version}.tar.gz"

[ "$(id -u)" -ne 0 ] || { echo "non eseguire come root" >&2; exit 1; }
for c in git curl sha256sum; do command -v "$c" >/dev/null || { echo "manca $c" >&2; exit 1; }; done

mkdir -p "$work" "$out"
sum=$(curl -fsSL "$url" | sha256sum | cut -d' ' -f1)
[ -n "$sum" ] && [ "$sum" != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ] \
    || { echo "tarball $url vuoto o assente: il tag v${version} esiste?" >&2; exit 1; }
echo "v${version}: sha256 $sum"

if [ -d "$work/void-packages/.git" ]; then
    git -C "$work/void-packages" pull --ff-only --depth 1
else
    git clone --depth 1 https://github.com/void-linux/void-packages "$work/void-packages"
fi
cd "$work/void-packages"

mkdir -p srcpkgs/vela
sed -e "s/^version=.*/version=${version}/" -e "s/^revision=.*/revision=1/" -e "s/^checksum=.*/checksum=${sum}/" \
    "$root/packaging/void/vela/template" > srcpkgs/vela/template

./xbps-src binary-bootstrap
./xbps-src -A x86_64 pkg vela

cp -v hostdir/binpkgs/vela-*.xbps "$out"/
echo "pacchetti in $out"
