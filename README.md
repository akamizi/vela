<p align="center"><img src="assets/logo.svg" alt="Logo di Vela" width="120"></p>

<h1 align="center">Vela</h1>

Shell minimale per Sway su Void Linux (barra, launcher, pannelli), basata su Quickshell.
Licenza: EUPL-1.2.

Versione 0.4.0: barra, menu/launcher con calcolatrice, pannelli (rete, Bluetooth, audio, luminosità, energia, limite di carica della batteria, radio, scorciatoie), OSD, notifiche, Impostazioni (con blocco e inattività distinti tra batteria e rete, applicazioni predefinite, radio, batteria, Informazioni) per Sway; interfaccia traducibile (per ora italiano).

## Requisiti

Obbligatori: `quickshell` (≥ 0.3) con i moduli Quickshell usati (`scripts/check-deps.sh` li elenca) e `sway`.
Facoltativi — se mancano, la voce relativa sparisce o mostra "non disponibile" e la shell parte lo stesso:
`brightnessctl` (luminosità), PipeWire (audio), NetworkManager e `nmcli` (rete, VPN), BlueZ (Bluetooth),
`power-profiles-daemon`, UPower (batteria), `gammastep` (luce notturna), `curl` (meteo), `dunstctl` (solo
per "non disturbare" se si usa dunst al posto delle notifiche integrate).

## Misure

A riposo su un portatile con Sway e un solo schermo: circa 195 MB di RAM e meno dell'1 % di CPU; la parte
fissa di Qt/Quickshell è circa 170 MB. Tolti Waybar, `dunst` e `wob`, che Vela sostituisce, il consumo totale
sale in RAM ma scende in CPU. Dettagli e motivazione in `DECISIONI.md` (D-010).

## Installazione (pacchetto Void)

Quando il pacchetto è nel repository: `xbps-install vela`. Installa il comando `/usr/bin/vela`, il QML e i
default in `/usr/share/vela`, gli esempi di configurazione in `/usr/share/doc/vela`. Da sorgente:
`make install PREFIX=/usr` (accetta `DESTDIR`). Il template xbps-src è in `packaging/void/vela/template`
(da completare con indirizzo e checksum della release).

Aggiungere a `~/.config/sway/config`:

```
exec vela                                           # avvia la shell (barra, menu, pannelli, OSD)
bindsym $mod+Ctrl+m exec vela ipc call menu toggle  # menu completo
bindsym $mod+Ctrl+a exec vela ipc call menu apps    # solo applicazioni
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
```

Se in Sway `~/.local/bin` non è nel PATH si usa il percorso completo. Barra e notifiche di altri programmi
(Waybar, dunst, mako, wob) vanno fermate: Vela le sostituisce (le notifiche integrate sono spente di default,
vedi sotto).

## Prova in sviluppo

```sh
scripts/check-deps.sh      # controlla Quickshell e i moduli
scripts/vela               # avvia la shell (barra in basso; Waybar non viene toccata)
```

Per fermare Vela: `pkill -x quickshell` oppure Ctrl+C nel terminale.

## Configurazione

Strati, dal più debole al più forte:

1. `config/defaults/*.jsonc` (nel repository)
2. `~/.config/vela/*.jsonc` (override utente, merge chiave per chiave)

Esempi in `config/user.example/`. Un override con errori di sintassi o di tipo
viene ignorato (in tutto o per la chiave interessata) e un avviso compare nella barra.
La configurazione utente è ricaricata a caldo se `~/.config/vela/` esiste all'avvio.

Variabile per i test: `VELA_USER_DIR` sostituisce `~/.config/vela`.

## Barra

Tre zone (sinistra, centro, destra) riempite dagli elementi elencati in `bar.modules` (`config/defaults/shell.jsonc`).
Elementi: Menu, Workspaces, WindowTitle, Weather, Recording, Dnd, NightLight, Awake, Media, Clock, Tray, Memory, Cpu,
Temperature, Fan, Bluetooth, Network, Vpn, Volume, Brightness, PowerProfile, Battery.
Quelli che dipendono da hardware o servizi assenti (batteria, ventola, retroilluminazione, Bluetooth, VPN) si nascondono da soli.

Interazioni: rotellina su Volume (±2%), Brightness (±5%), Workspaces e Media; clic destro su Volume (muto) e Bluetooth
(on/off); clic su Clock (formato alternativo), PowerProfile (profilo successivo), Vpn (accendi/spegni), Tray (attiva; destro = menu).
Passando il mouse compaiono i tooltip (calendario sull'orologio, previsioni sul meteo).

## Menu / launcher

Menu unico con ricerca fuzzy su voci di menu (anche annidate) e applicazioni `.desktop`.
Si apre dal pulsante della barra o da scorciatoia Sway:

```
bindsym $mod+<tasto> exec ~/.local/bin/vela ipc call menu toggle   # menu completo
bindsym $mod+<tasto> exec ~/.local/bin/vela ipc call menu apps     # solo applicazioni
```

Nota: Sway non ha `~/.local/bin` nel PATH, quindi nelle scorciatoie serve il percorso completo del comando `vela`.

Tasti: Su/Giù (o Ctrl+J/K), Invio = esegui, Destra = entra in un sottomenu, Sinistra o Backspace a campo vuoto = indietro,
Esc = cancella il testo / torna indietro / chiude. Le voci con `confirm` chiedono conferma con Invio.

Le voci si definiscono in `config/defaults/menu.jsonc`; l'override utente `~/.config/vela/menu.jsonc` si fonde **per id**
(vedi i commenti nel file e `config/user.example/menu.jsonc`). Le azioni `exec` sono sempre array di argomenti.

## Resta sveglio

Mentre è attivo la barra mostra una pillola arancione "SVEGLIO" (clic = disattiva). Di base è l'inibitore di
idle di Vela (voce Interruttori › Resta sveglio, o `vela ipc call toggles awake`). Se usi uno script esterno
(ad esempio uno che ferma `swayidle`) configura in `shell.jsonc` `toggles.awakeCommand` (esce con 0 se è
attivo) e `toggles.awakeToggleCommand` (lo commuta): l'indicatore e la voce di menu li seguiranno, e lo script
può chiamare `vela ipc call toggles refresh` per un aggiornamento immediato (altrimenti entro 5 secondi).

## Impostazioni

`vela ipc call panel toggle settings` o menu Sistema › Impostazioni: finestra al centro con le categorie a
sinistra. **Barra**: posizione, altezza, dimensione del testo e angoli (della barra, separati dagli altri), trasparenza e gli elementi (←/→ li sposta tra Sinistra, Centro,
Destra e Nascosto, Maiusc+↑/↓ li riordina). **Tema**: preset scuro/chiaro, colori (Invio: campo `#rrggbb` con quadrato saturazione/luminosità, barra del tono e tavolozza; si può anche scrivere il codice),
carattere, dimensione, angoli di pannelli, menu e notifiche. ←/→ cambia i valori, Canc ripristina il valore di default, Tab cambia categoria.
L'effetto è immediato. Le scelte vanno in `~/.config/vela/settings.jsonc`, che ha la precedenza sugli altri
file: i tuoi `shell.jsonc`, `theme.jsonc` e `menu.jsonc` non vengono mai modificati da Vela.

La categoria **Meteo** imposta la città e le unità. "Città": Invio, scrivi il nome e scegli tra i risultati
(la ricerca usa il servizio di geocodifica di Open-Meteo e invia solo il nome cercato, solo quando la avvii);
le coordinate e il nome finiscono in `settings.jsonc`. "Unità di misura": metriche (°C, predefinito) o
imperiali (°F). Senza città il meteo resta spento. Canc sulla città ripristina.

Con Sway come compositor compaiono anche **Schermi** (risoluzione e frequenza, scala, rotazione, posizione e
accensione con più schermi: dopo ogni modifica hai 15 secondi per confermare, altrimenti si torna indietro),
**Tastiera e touchpad** (layout, variante, opzioni, ripetizione; tocco, scorrimento naturale, disattiva mentre
si scrive, velocità) e **Sfondo** (immagine con percorso assoluto e adattamento, oppure un colore). Tastiera,
touchpad e sfondo si applicano subito con `swaymsg`; Canc torna al valore predefinito (lo stato attuale di Sway
cambia al prossimo `swaymsg reload`). Vela scrive `~/.config/vela/sway.d/vela.conf`; perché valga anche dopo il
login, il config di Sway deve includerlo: la categoria **Compositor** ha l'azione "Aggiungi la riga include"
(chiede conferma e fa una copia `config.bak-vela-include`), oppure aggiungi tu `include ~/.config/vela/sway.d/*.conf`.

**Scorciatoie** elenca quelle del tuo config di Sway (sola lettura) e le tue di Vela: Invio su una del config
ne cambia il comando (vuoto = disattiva) scrivendo una sostituzione in `vela.conf`, Canc toglie la sostituzione;
"Aggiungi una scorciatoia" chiede combinazione e comando e avvisa se la combinazione è già assegnata.
**Avvio automatico** e **Regole delle finestre** funzionano allo stesso modo (gli avvii di Vela partono dal
prossimo login e richiedono l'include). **Bordi e spazi**: spazio tra le finestre e dal bordo dello schermo,
spessore del bordo (per le finestre nuove), niente spazi o bordi con una sola finestra.

**Blocco e inattività**: Vela può gestire da sé l'inattività (spenta di default: va attivata solo se non usi
già `swayidle`). Dopo X minuti blocca lo schermo (comando configurabile, `swaylock -f` di default), dopo Y lo
spegne e dopo Z sospende (di default solo a batteria); 0 = mai. Rispetta le finestre a schermo intero e
"Resta sveglio". `vela ipc call idle lock` blocca subito. Per passare a Vela togli `swayidle` dal config del
compositor (il pannello avvisa se è in esecuzione). Chiusura del coperchio e pulsante di accensione dipendono da
elogind e non sono ancora configurabili da qui.

**App predefinite**: sceglie, per ogni tipo di file, l'applicazione che lo apre: browser web, gestore di file,
editor di testo, lettore PDF, immagini, video, audio e client di posta. Legge lo stato con `xdg-mime query
default` e scrive `~/.config/mimeapps.list` (con `xdg-mime` e `xdg-settings`); le applicazioni candidate sono i
file `.desktop` che dichiarano quel tipo.

La categoria **Informazioni** mostra il logo, la versione, la licenza, il compositor e i link al progetto.

La categoria **Compositor** mostra quali compositor ci sono (installato, in esecuzione, sessione attuale), se
Vela ha un backend per quello attivo e quali categorie di impostazioni sono già disponibili o in arrivo
(schermi, tastiera e touchpad, sfondo, scorciatoie, avvio automatico, regole, bordi). Oggi il backend è Sway.

## OSD e notifiche

L'OSD di volume e luminosità (`osd.enabled`) compare a ogni cambio e sostituisce `wob`. Il server di
notifiche integrato (`notifications.enabled`, spento per default) sostituisce `dunst`: va attivato solo dopo
aver fermato dunst/mako, perché un solo programma alla volta può possedere `org.freedesktop.Notifications`.
Testo sempre semplice, clic = chiudi, le notifiche critiche restano finché non si chiudono.
"Non disturbare" (`vela ipc call toggles dnd` o la voce nel menu) scarta quelle non critiche.

## Lingua

Vela è in italiano; i testi sono traducibili (D-028). `language` in `~/.config/vela/shell.jsonc` (es. `"en"`; vuoto = lingua
dell'ambiente, poi italiano). I cataloghi stanno in `i18n/<lingua>.json` (italiano → traduzione); i propri in
`~/.config/vela/i18n/<lingua>.json`. Una voce mancante o vuota mostra l'italiano. Per tradurre: `scripts/i18n-extract --update xx`
crea il catalogo con tutte le chiavi, poi si riempiono i valori.

## Limite di carica della batteria

Sui portatili che lo permettono, il clic sull'icona della batteria apre un pannello con l'interruttore del limite di carica e
"Carica al 100% una volta" (poi il limite torna da solo). Stesse azioni nelle Impostazioni › Batteria. Su un PC senza questa funzione non compare nulla.
Serve la parte di sistema (helper di root, regola polkit per il gruppo `wheel`, regola udev): `doas make install-system`.
Funziona con le soglie regolabili (ThinkPad, 75/80) e con il limite fisso del firmware (IdeaPad, `charge_types`).

## Calcolatrice

`vela ipc call menu calc` (o, nel menu, "=" davanti): scrivi un'espressione (`2+3*4`, `100 km to miles`, `5 EUR to USD`) e Invio copia
il risultato negli appunti. Anche una ricerca che somiglia a un'espressione mostra il risultato in cima. Serve `qalc` (libqalculate) e `wl-copy`.

## Tasti di sistema (IPC)

Per le scorciatoie di Sway: `vela ipc call audio raise|lower|mute|micMute`, `brightness up|down`, `screens on|off`,
`idle lock`, `toggles touchpad|awake|night|dnd`. I passi di volume e luminosità sono in `audio.step` e `brightness.step`.

## Pannello luminosità

Clic sull'icona della luminosità nella barra (la rotellina cambia di ±5%), menu Sistema › Luminosità o
`vela ipc call panel toggle brightness`. Cursore trascinabile; ←/→ = passo, PagSu/PagGiù = ±20%, 1-9 = 10-90%, 0 = 100%.

## Pannello energia

Clic sull'icona del profilo energetico (clic destro o rotellina = profilo successivo), menu Sistema › Energia o
`vela ipc call panel toggle power`. Risparmio energetico, Bilanciato e, se il sistema lo offre, Prestazioni:
Invio o clic = attiva, 1/2/3 = scelta diretta. Usa power-profiles-daemon.

## Web radio

`vela ipc call panel toggle radio` o menu Sistema › Radio: le stazioni di `radio.stations`
(`[{ "name": "Rai Radio 3", "url": "http://icestreaming.rai.it/3.mp3" }]` in `~/.config/vela/shell.jsonc`).
Invio o clic = ascolta (di nuovo = ferma), digitando si filtra. Le stazioni si gestiscono da Impostazioni › Radio (aggiungi, modifica, rimuovi, riordina). Serve `mpv` (o un altro player in `radio.command`).
L'elemento di barra `Radio` compare mentre suona: clic = pannello, clic destro = ferma.
`vela ipc call radio stop` e `vela ipc call radio play "Rai Radio 3"` per le scorciatoie.

## Pannello delle scorciatoie

`vela ipc call panel toggle shortcuts` o menu Sistema › Scorciatoie: finestra al centro con le scorciatoie attuali,
composte da sole dal config di Sway e dalle scorciatoie di Vela (nessun elenco da tenere aggiornato). Si digita per
filtrare, ↑/↓ scorrono, Esc cancella il filtro e poi chiude. Per dare un nome a una scorciatoia di Sway basta un
commento in coda alla riga: `bindsym $mod+t exec foot  # Terminale`.

## Pannello audio

(Stile Omarchy, D-023: intestazione con uscita predefinita e interruttore del muto, cursori del volume per dispositivo.)

Clic sull'icona del volume (clic destro = muto, rotellina = volume), menu Sistema › Audio o
`vela ipc call panel toggle audio`. Uscite e ingressi con volume per dispositivo: ←/→ = volume,
M = muto, Invio = rendi predefinito, Esc = chiude.

## Pannello Bluetooth

(In stile Omarchy, D-023: intestazione con interruttore, sezioni, righe con stati; si apre sotto o sopra l'icona
della barra che l'ha aperto.) In più: Spazio = accendi/spegni.


Clic sull'icona Bluetooth (clic destro = accendi/spegni), menu Sistema › Bluetooth o
`vela ipc call panel toggle bluetooth`. Elenca i dispositivi accoppiati e quelli trovati dalla scansione
(attiva solo a pannello aperto). Invio = connetti/disconnetti/accoppia, Canc = dimentica, Esc = chiude.
Dispositivi che chiedono un PIN non sono ancora supportati.

## Pannello rete

(Stile Omarchy, D-023: intestazione con interruttore Wi-Fi, reti con stati, VPN con interruttori; Spazio = Wi-Fi acceso/spento.)

Si apre con un clic sull'icona di rete o sulla VPN nella barra, dal menu (Sistema › Rete) o con
`vela ipc call panel toggle network`. Mostra Wi-Fi (interruttore, reti per segnale), cavo e VPN.
Invio = connetti/disconnetti (rete nuova protetta: campo password), Canc = dimentica la rete salvata,
Esc = indietro/chiude, clic fuori = chiude. La password passa direttamente a NetworkManager e non viene
salvata né registrata. Le reti aziendali (802.1x) vanno configurate con `nm-connection-editor`.

## Comandi alla shell in esecuzione

```sh
scripts/vela ipc show                   # funzioni disponibili
scripts/vela ipc call menu toggle       # apre/chiude il menu (menu apps = solo app)
scripts/vela ipc call panel toggle network   # apre/chiude il pannello rete
scripts/vela ipc call bar toggle        # mostra/nascondi la barra (sostituisce Win+B di Waybar)
scripts/vela ipc call toggles awake     # resta sveglio (inibisce l'idle)
scripts/vela ipc call toggles night     # luce notturna (gammastep)
scripts/vela ipc call toggles dnd       # non disturbare (provvisorio: dunst)
```
