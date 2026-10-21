#!/bin/sh
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# Crea (o rigenera) il repository xbps in <repo> a partire dai .xbps di <pacchetti>, firmandolo.
#
# Uso: scripts/publish-xbps-repo.sh <pacchetti> <repo> <chiave-privata.pem> ["Nome del firmatario"]
# La chiave si crea una volta: `openssl genrsa -out vela-repo.pem 4096` (da tenere fuori dal repository).
# Il repository contiene solo le versioni date: ogni pubblicazione lo sostituisce, non si accumulano file.
set -eu

[ $# -ge 3 ] || { sed -n '4,6p' "$0" >&2; exit 1; }
pkgs=$1; repo=$2; key=$3; signer=${4:-"Vela"}
command -v xbps-rindex >/dev/null || { echo "manca xbps-rindex" >&2; exit 1; }
[ -r "$key" ] || { echo "chiave non leggibile: $key" >&2; exit 1; }
ls "$pkgs"/*.xbps >/dev/null 2>&1 || { echo "nessun .xbps in $pkgs" >&2; exit 1; }

rm -rf "$repo"; mkdir -p "$repo"
cp "$pkgs"/*.xbps "$repo"/
xbps-rindex -a "$repo"/*.xbps
xbps-rindex --privkey "$key" --signedby "$signer" --sign "$repo"
xbps-rindex --privkey "$key" --sign-pkg "$repo"/*.xbps
echo "repository pronto in $repo:"; ls "$repo"
