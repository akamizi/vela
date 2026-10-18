# Vela

Shell minimale per Sway su Void Linux (barra, launcher, pannelli), basata su Quickshell.
Licenza: EUPL-1.2.

Stato: sviluppo, Fase 8 (barra, menu/launcher, pannelli rete, Bluetooth e audio, OSD, notifiche). Vedi `PIANO.md` nella cartella padre del progetto.

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

## OSD e notifiche

L'OSD di volume e luminosità (`osd.enabled`) compare a ogni cambio e sostituisce `wob`. Il server di
notifiche integrato (`notifications.enabled`, spento per default) sostituisce `dunst`: va attivato solo dopo
aver fermato dunst/mako, perché un solo programma alla volta può possedere `org.freedesktop.Notifications`.
Testo sempre semplice, clic = chiudi, le notifiche critiche restano finché non si chiudono.
"Non disturbare" (`vela ipc call toggles dnd` o la voce nel menu) scarta quelle non critiche.

## Pannello audio

Clic sull'icona del volume (clic destro = muto, rotellina = volume), menu Sistema › Audio o
`vela ipc call panel toggle audio`. Uscite e ingressi con volume per dispositivo: ←/→ = volume,
M = muto, Invio = rendi predefinito, Esc = chiude.

## Pannello Bluetooth

Clic sull'icona Bluetooth (clic destro = accendi/spegni), menu Sistema › Bluetooth o
`vela ipc call panel toggle bluetooth`. Elenca i dispositivi accoppiati e quelli trovati dalla scansione
(attiva solo a pannello aperto). Invio = connetti/disconnetti/accoppia, Canc = dimentica, Esc = chiude.
Dispositivi che chiedono un PIN non sono ancora supportati.

## Pannello rete

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
