# Repository xbps di Vela

Pacchetto per Void (glibc, x86_64) costruito con `xbps-src` e servito da GitHub Pages come repository xbps firmato.

## Installare su un altro PC

```sh
echo 'repository=https://akamizi.github.io/vela/current' | doas tee /etc/xbps.d/20-vela.conf
doas xbps-install -S vela
```

Al primo `-S` xbps mostra l'impronta della chiave del repository e chiede di accettarla: va confrontata con quella
questa: `90:db:2f:97:18:f1:73:cd:c7:63:81:93:bb:2c:0a:8d`. Le dipendenze facoltative sono nel
`template` (NetworkManager, bluez, wireplumber, ...).

## Pubblicazione (una tantum)

1. Chiave di firma, fuori da ogni repository: `openssl genrsa -out vela-repo.pem 4096`.
2. Su GitHub: Settings › Secrets › Actions › `XBPS_PRIVKEY` = contenuto del file `.pem`.
3. Dopo la prima esecuzione dell'Action: Settings › Pages › Source = ramo `gh-pages`, cartella `/`.

A ogni tag `v*` l'Action `.github/workflows/xbps-repo.yml` costruisce il pacchetto e rigenera il ramo `gh-pages`
(solo la versione corrente, senza storico). Si può lanciare anche a mano (workflow_dispatch) indicando la versione.

## Prova in locale (senza GitHub)

```sh
scripts/build-xbps-direct.sh            # come l'Action: make install + xbps-create; .xbps in build-xbps/out
# oppure, con xbps-src (void-packages):
scripts/build-xbps.sh 0.16.0            # clona void-packages in build-xbps/work e costruisce; .xbps in build-xbps/out
scripts/publish-xbps-repo.sh build-xbps/out build-xbps/repo vela-repo.pem "Nome"
```

Provare il repository locale senza installare nulla: `xbps-query -i --repository=$PWD/build-xbps/repo -R vela`.

## Meta-pacchetto `vela-recommended`

`doas xbps-install vela-recommended` porta le dipendenze facoltative (elenco in `packaging/void/vela-recommended/template`); senza, resta il minimo
(`vela`) e le funzioni senza il loro programma spariscono. L'Action lo costruisce insieme a `vela` (`scripts/build-xbps-direct.sh`, `noarch`, senza file,
stessa versione). A ogni versione nuova cambia `version=` in **entrambi** i template.

## Script e messaggio di installazione

`packaging/void/vela/INSTALL` ricarica le regole udev dopo l'installazione (la regola del limite di carica si vede senza riavviare);
`INSTALL.msg` è il testo che xbps mostra a fine installazione (Sway, servizi, gruppi). Nessuno dei due attiva servizi, tocca le home o i gruppi (D-048).

## Limiti noti

- Solo x86_64 glibc (musl e altre architetture: da aggiungere).
- L'Action non usa `xbps-src` (nel container dei runner i namespace utente sono negati: `failed to write to /proc/self/uid_map`) ma `scripts/build-xbps-direct.sh`: niente controlli di xbps-src su librerie condivise e strip. `scripts/build-xbps.sh` resta per le costruzioni locali e per una futura proposta a void-packages.
- Il checksum nel `template` è quello dell'ultima release; lo script lo ricalcola a ogni costruzione.
- Il repository contiene solo l'ultima versione: chi non aggiorna può trovarsi con un pacchetto non più scaricabile.
