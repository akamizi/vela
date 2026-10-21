# Repository xbps di Vela

Pacchetto per Void (glibc, x86_64) costruito con `xbps-src` e servito da GitHub Pages come repository xbps firmato.

## Installare su un altro PC

```sh
echo 'repository=https://akamizi.github.io/vela/current' | doas tee /etc/xbps.d/20-vela.conf
doas xbps-install -S vela
```

Al primo `-S` xbps mostra l'impronta della chiave del repository e chiede di accettarla: va confrontata con quella
pubblicata nel README del progetto (`xbps-rindex`/`openssl`: vedi sotto). Le dipendenze facoltative sono nel
`template` (NetworkManager, bluez, wireplumber, ...).

## Pubblicazione (una tantum)

1. Chiave di firma, fuori da ogni repository: `openssl genrsa -out vela-repo.pem 4096`.
2. Su GitHub: Settings › Secrets › Actions › `XBPS_PRIVKEY` = contenuto del file `.pem`.
3. Dopo la prima esecuzione dell'Action: Settings › Pages › Source = ramo `gh-pages`, cartella `/`.

A ogni tag `v*` l'Action `.github/workflows/xbps-repo.yml` costruisce il pacchetto e rigenera il ramo `gh-pages`
(solo la versione corrente, senza storico). Si può lanciare anche a mano (workflow_dispatch) indicando la versione.

## Prova in locale (senza GitHub)

```sh
scripts/build-xbps.sh 0.7.0            # clona void-packages in build-xbps/work e costruisce; .xbps in build-xbps/out
scripts/publish-xbps-repo.sh build-xbps/out build-xbps/repo vela-repo.pem "Nome"
```

Provare il repository locale senza installare nulla: `xbps-query -i --repository=$PWD/build-xbps/repo -R vela`.

## Limiti noti

- Solo x86_64 glibc (musl e altre architetture: da aggiungere).
- Il container dell'Action usa `--privileged` per i namespace di `xbps-src`: da verificare alla prima esecuzione.
- Il checksum nel `template` è quello dell'ultima release; lo script lo ricalcola a ogni costruzione.
- Il repository contiene solo l'ultima versione: chi non aggiorna può trovarsi con un pacchetto non più scaricabile.
