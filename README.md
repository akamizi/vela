<p align="center"><img src="assets/logo.svg" alt="Logo di Vela" width="120"></p>

<h1 align="center">Vela</h1>

Shell minimale per Sway su Void Linux (barra, launcher, pannelli), basata su Quickshell.
Licenza: EUPL-1.2.

Versione 0.14.7: `Win+T` apre l'editor di testo predefinito (`vela editor`, col tema di Vela se è FeatherPad, che al primo avvio parte con lo schema colore scuro). Versione 0.14.6: `vela-recommended` installa anche FeatherPad (editor di testo Qt minimale). Versione 0.14.5: `Win+I` apre le Impostazioni ("Resta sveglio" passa a `Win+Shift+I`); la sessione «Vela» avvia l'agente polkit Qt (`lxqt-policykit`) e il portale dei selettori di file Qt (`xdg-desktop-portal-lxqt`) con il tema di Vela, riferimento delle preferenze dei portali in `/usr/share/vela/portals.conf`; `vela-recommended` installa anche `lxqt-policykit`, `xdg-desktop-portal-lxqt` e `yazi`. Versione 0.14.4: corretto il blocco schermo (`Win+L`, `vela ipc call idle lock`), che non lanciava swaylock;  nella sessione «Vela» blocco schermo, schermo spento e sospensione per inattività sono accesi da soli (`idle.enabled: null` = automatico). Versione 0.14.3: `Win+F` apre il gestore di file predefinito col tema di Vela se è PCManFM-Qt (`vela files`). Versione 0.14.2: radio predefinite verificate, `Win+F` apre il gestore di file predefinito, notifiche di Vela accese da sole nella sessione «Vela» (dunst non serve più), scheda Sfondo con selettore grafico delle immagini. Versione 0.14.1: l'elemento di barra `User` mostra l'icona dell'omino al posto della foto (la foto resta nel pannello). Dalla 0.14.0: elemento di barra `User` (ultimo a destra: icona dell'omino) e pannello utente (`vela ipc call panel toggle user`, `Win+U`): foto, nome, `utente@computer`, tempo di attività, riga di stato (batteria, rete, profilo energetico) e le azioni Impostazioni, Blocca, Sospendi, Esci, Riavvia, Spegni (le ultime tre chiedono conferma; lettera della riga = scelta diretta). Dalla 0.13.0: tasti predefiniti della sessione Vela rifatti (terminale, file manager, browser e posta predefiniti, menu, calcolatrice, scorciatoie, energia, radio, blocco, ridimensiona, schermate con grim + slurp + swappy, spazi di lavoro con Ctrl+Alt+frecce; l'elenco è in `session/sway-config` e nel pannello Scorciatoie, `Win+Z`), `vela ipc call menu power` apre direttamente la sezione Alimentazione (`Ctrl+Win+Spazio`), `vela-recommended` installa anche `grim slurp swappy xdg-utils`. Dalla 0.12.3: il pacchetto xbps ha le dipendenze con versione (`nome>=0`), quindi `xbps-install vela` non si ferma più con «can't guess pkgname» se `quickshell` non è installato. Dalla 0.12.2: `vela-recommended` installa anche `lxqt-archiver`; ritocchi al tema Qt (padding delle voci di menu, spazio sopra le icone nella vista dei file) e `~/.config/vela/qt.qss` per provare regole QSS proprie. Dalla 0.12.1: `vela-recommended` installa anche `papirus-icon-theme` e `vela theme qt` ripiega su `Papirus-Dark` se il tema delle icone scelto manca. Dalla 0.12.0: `vela theme qt` (tema Qt dai token di `theme.jsonc`: foglio di stile, palette e icone Nordzy-dark solo per il programma lanciato; voce di menu «File» per PCManFM-Qt, `pcmanfm-qt` in `vela-recommended`; riga «Tema delle icone» in Impostazioni › Tema). Dalla 0.11.0: meta-pacchetto `vela-recommended` (`xbps-install vela-recommended` porta le dipendenze facoltative). Dalla 0.10.0: sessione «Vela» per il login manager (Sway con la configurazione di Vela, senza toccare `~/.config/sway/config`; `vela-session`), script di installazione del pacchetto (ricarica udev) e messaggio con i passi manuali, checklist «Primo avvio». Dalla 0.9.0: pannello Servizi (runit: stato senza privilegi, avvia/ferma/riavvia/abilita/disabilita nel terminale con `doas`, che chiede la password; `vela ipc call services …`). Dalla 0.8.0: pannello Stampanti (CUPS: stato, predefinita, ferma/riprendi, coda dei lavori, ricerca e aggiunta senza driver, rimozione; compare solo con `lpstat`; `vela ipc call printers …`), repository xbps su GitHub Pages (`packaging/void/README.md`). Dalla 0.7.0: pannello Schermi (modalità solo interno / solo esterni / estendi / duplica con `wl-mirror`, disposizione visiva con due schermi, risoluzione e scala, luminosità e luce notturna, conferma di 15 secondi; `vela ipc call display …`). Dalla 0.6.0: chiusura ordinata delle finestre alla fine sessione, indicatore e ciclo della disposizione delle finestre (`WindowLayout`, `vela ipc call layout next`), notifiche raggruppate per mittente (e correzione della durata esplicita delle app), indicatori raggruppati (`Indicators`). Dalla 0.5.0: helper della batteria in Rust, demone dati `vela-daemon`, spazio tra i gruppi della barra, nuovo logo. Comprende: barra, menu/launcher con calcolatrice, pannelli (rete, Bluetooth, audio, schermi, stampanti, servizi, luminosità, energia, limite di carica della batteria, radio, scorciatoie), OSD, notifiche, Impostazioni (con blocco e inattività distinti tra batteria e rete, applicazioni predefinite, radio, batteria, Informazioni) per Sway; interfaccia traducibile (per ora italiano).

## Requisiti

Obbligatori: `quickshell` (≥ 0.3) con i moduli Quickshell usati (`scripts/check-deps.sh` li elenca) e `sway`.
Per compilare da sorgente: `cargo` (l'helper della batteria e il demone dati sono programmi Rust, solo libreria standard).
Facoltativi — se mancano, la voce relativa sparisce o mostra "non disponibile" e la shell parte lo stesso:
`brightnessctl` (luminosità), PipeWire (audio), NetworkManager e `nmcli` (rete, VPN), BlueZ (Bluetooth),
`power-profiles-daemon`, UPower (batteria), `gammastep` (luce notturna), `curl` (meteo), `dunstctl` (solo
per "non disturbare" se si usa dunst al posto delle notifiche integrate).

## Misure

A riposo su un portatile con Sway e un solo schermo (misura del 2026-10-20, con demone dati): circa 230 MB di RAM
(RSS) e 0,4 % di CPU, nessun processo lanciato periodicamente; il demone aggiunge circa 2 MB e 0,3 % di CPU. La parte
fissa di Qt, Quickshell e del driver grafico è la maggioranza della memoria. Tolti Waybar, `dunst` e `wob`, che Vela
sostituisce, il consumo totale sale in RAM ma scende in CPU. Dettagli in `DECISIONI.md` (D-010, D-039).

## Installazione (pacchetto Void)

Quando il pacchetto è nel repository: `xbps-install vela`. Installa il comando `/usr/bin/vela`, il QML e i
default in `/usr/share/vela`, gli esempi di configurazione in `/usr/share/doc/vela`. Da sorgente:
`make` (come utente: compila l'helper della batteria e il demone dati) e poi `make install PREFIX=/usr` (accetta
`DESTDIR`). La parte con privilegi (helper di root, regola polkit, regola udev) si installa anche da sola con
`doas make install-system`. Il template xbps-src è in `packaging/void/vela/template` (ancora da provare con xbps-src).

Aggiungere a `~/.config/sway/config`:

```
exec vela                                           # avvia la shell (barra, menu, pannelli, OSD)
bindsym $mod+Ctrl+m exec vela ipc call menu toggle  # menu completo
bindsym $mod+Ctrl+a exec vela ipc call menu apps    # solo applicazioni
bindsym $mod+Tab exec vela ipc call layout next      # cambia la disposizione delle finestre (indicatore WindowLayout)
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
```

Se in Sway `~/.local/bin` non è nel PATH si usa il percorso completo. Barra e notifiche di altri programmi
(Waybar, dunst, mako, wob) vanno fermate: Vela le sostituisce (le notifiche integrate sono spente di default,
vedi sotto).

## Primo avvio (su un PC nuovo)

Il pacchetto non modifica file dell'utente: dopo `xbps-install` restano da fare queste cose a mano.

1. **Repository** (se non è nei repository ufficiali): `echo 'repository=https://akamizi.github.io/vela/current' | doas tee /etc/xbps.d/20-vela.conf`,
   poi `doas xbps-install -S vela`. Al primo `-S` xbps mostra l'impronta della chiave: deve essere
   `90:db:2f:97:18:f1:73:cd:c7:63:81:93:bb:2c:0a:8d`.
2. **Sway**: la via più semplice è scegliere la sessione **«Vela»** dal login manager (vedi «Sessione Vela» sotto): non serve toccare nulla. Con la
   propria sessione Sway: aggiungere a `~/.config/sway/config` le righe `exec vela` e le scorciatoie (sezione sopra), togliere il blocco `bar { … }` di Sway
   e fermare Waybar, dunst, mako e wob. Ricaricare Sway.
3. **Servizi di sistema** (runit: `doas ln -s /etc/sv/<servizio> /var/service/`), solo per le funzioni che servono:
   `dbus` ed `elogind` (sessione), `NetworkManager` (rete), `bluetoothd` (Bluetooth), `cupsd` e `avahi-daemon` (stampanti),
   `power-profiles-daemon` (profili energetici); l'audio usa PipeWire e WirePlumber avviati dalla sessione.
4. **Gruppi** (poi rifare il login): `network` (azioni di rete), `lpadmin` (fermare, aggiungere e rimuovere stampanti), `wheel` (limite di carica
   della batteria senza password, in sessione locale). Per i servizi runit serve `doas` (o `sudo`) configurato per l'utente.
5. **Facoltativi** (se mancano la voce sparisce o dice «non disponibile»): il modo più semplice è il meta-pacchetto **`vela-recommended`**
   (`doas xbps-install vela-recommended`: NetworkManager, bluez, PipeWire e WirePlumber, upower, power-profiles-daemon, brightnessctl, gammastep, curl,
   cups, avahi, wl-mirror, polkit (con agente Qt `lxqt-policykit`), portali (wlr e lxqt), swaylock, swayidle, libnotify). Chi vuole il minimo installa solo `vela` e aggiunge ciò che gli serve. Controllo rapido: `scripts/check-deps.sh` (dal sorgente).
6. **Notifiche**: nella sessione «Vela» sono accese da sole (`notifications.inVelaSession`, default `true`). In un Sway tuo sono spente di default: per usare quelle di Vela, `notifications.enabled: true` in `~/.config/vela/shell.jsonc` (e fermare altri server di notifiche, come dunst).
7. **Portatili**: la regola udev del limite di carica si applica con `doas udevadm control --reload` o al riavvio; poi `battery-limit status`
   (in `/usr/libexec/vela/`) deve rispondere. Funziona solo se il portatile espone le soglie in sysfs.
8. **Configurazione**: non serve nessun file, partono i default del pacchetto. Per cambiare qualcosa: pannello Impostazioni
   (scrive `~/.config/vela/settings.jsonc`) oppure i file a mano in `~/.config/vela/` (vedi `/usr/share/doc/vela`).

## Tema per le app Qt (`vela theme qt`)

`vela theme qt` genera un foglio di stile Qt (QSS) **dagli stessi token di `theme.jsonc`** (colori, font Inter, stati hover/selezione, angoli) e lo salva in
`~/.local/share/vela/qt/vela.qss`; `vela theme qt print` lo stampa e `vela theme qt run <programma> [argomenti]` lo rigenera e lancia il programma Qt con
`-style fusion -stylesheet …` e il tema delle icone di `qt.iconTheme` in `theme.jsonc` (default `Nordzy-dark`, da installare in `~/.local/share/icons`; se manca si ripiega su `Papirus-Dark`, che `vela-recommended` installa; vuoto = icone del tema GTK). Così le app Qt, per esempio **PCManFM-Qt** (voce di menu «File», se
installato), seguono il tema di Vela senza toccare `~/.config/pcmanfm-qt` né installare `qt6ct`/Kvantum; il tema si applica **solo** al programma lanciato, non a
Quickshell né al resto della sessione. Serve Vela in esecuzione (altrimenti usa l'ultimo foglio salvato). Le icone arrivano da un `kdeglobals` privato (`~/.local/share/vela/qt/kde/`, cercato via `XDG_CONFIG_DIRS` con il tema piattaforma «kde», solo per quel processo; `qt6ct` non permette una cartella privata). Per provare spazi e padding senza toccare il codice si può creare `~/.config/vela/qt.qss` (regole QSS aggiunte in coda al foglio generato; esempio: `QTreeView::item { padding: 4px 6px; }`).
Palette e bordi seguono il tema (bordi come nei pannelli, non il colore `border`). Le dimensioni delle icone sono del programma (PCManFM-Qt: Preferenze › Visualizzazione). Limiti: le icone sono a colori, non i glifi di
Vela; il QSS non cambia la struttura dell'interfaccia.

## Sessione Vela

Il pacchetto installa una voce **«Vela»** per il login manager (`/usr/share/wayland-sessions/vela.desktop`, per greetd/tuigreet, ly, sddm...): avvia
`vela-session`, cioè Sway con la configurazione di sistema `/usr/share/vela/sway/config` dentro una sessione D-Bus. Quella configurazione avvia Vela
(`exec vela`), non ha nessuna barra di Sway e dà le scorciatoie di base (finestre, spazi di lavoro 1-9, menu, layout con Super+Tab, tasti
audio e luminosità con l'OSD, Super+Maiusc+L blocca, Super+Maiusc+E esce). `/usr/libexec/vela/session-init` avvia, se ci sono e non sono già attivi,
PipeWire, l'agente polkit Qt e i portali (condivisione schermo, selettori di file Qt, tutti col tema di Vela). **Non tocca `~/.config/sway/config`**: la tua sessione Sway normale resta com'è.
Personalizzazioni (layout di tastiera, sfondo, touchpad, altre scorciatoie): file `~/.config/vela/sway.d/*.conf`, inclusi in fondo (vincono).
Non parte: il portachiavi, applet di rete o servizi di sistema (i servizi runit restano da collegare, vedi «Primo avvio»).

## Prova in sviluppo

```sh
scripts/check-deps.sh      # controlla Quickshell e i moduli
scripts/vela               # avvia la shell (barra in basso; Waybar non viene toccata)
```

Spegni, Riavvia ed Esci dal menu chiudono prima le finestre in ordine (le app possono salvare) e agiscono quando non ne resta
nessuna; se dopo 10 s ce n'è ancora qualcuna annullano e avvisano con una notifica (`session.closeWindows`, `session.closeTimeout`;
anche `vela ipc call session poweroff|reboot|logout`).

Per fermare Vela: `pkill -x quickshell` oppure Ctrl+C nel terminale.

Il demone dati (`make daemon`) e l'helper della batteria vanno installati in `/usr/libexec/vela/` per essere usati; in
sviluppo si può puntare il demone al binario compilato con `daemon.command` in `~/.config/vela/shell.jsonc`
(`daemon/target/release/vela-daemon`). Senza demone Vela funziona come prima, con i controlli periodici nel QML;
dopo aver sostituito il binario basta fermare il processo `vela-daemon` e Vela lo rilancia.

## Configurazione

Strati, dal più debole al più forte:

1. `config/defaults/*.jsonc` (nel repository)
2. `~/.config/vela/*.jsonc` (override utente, merge chiave per chiave)

Esempi in `config/user.example/`. Un override con errori di sintassi o di tipo
viene ignorato (in tutto o per la chiave interessata) e un avviso compare nella barra.
La configurazione utente è ricaricata a caldo se `~/.config/vela/` esiste all'avvio.

Variabile per i test: `VELA_USER_DIR` sostituisce `~/.config/vela`.

## Barra

Tre zone (sinistra, centro, destra) riempite dagli elementi elencati in `bar.modules` (`config/defaults/shell.jsonc`). Gli elementi dello stesso gruppo (`bar.groups`: hardware, stato, rete, audio, energia) stanno vicini; tra gruppi diversi c'è lo spazio `bar.groupGap` (px), e un gruppo senza elementi visibili non lascia vuoti.
Elementi: Menu, Workspaces, WindowLayout, WindowTitle, Weather, Indicators, Recording, Dnd, NightLight, Awake, Media, Radio, Clock, Tray, Memory, Cpu,
Temperature, Fan, KeyboardLayout, Updates, Bluetooth, Network, Vpn, Mic, Volume, Brightness, PowerProfile, Battery.
Mic è spento di default; KeyboardLayout compare solo con più di un layout e Updates solo con aggiornamenti disponibili.
Indicators raggruppa in un solo elemento i modi accesi (Recording, Dnd, NightLight, Awake): un clic su un simbolo lo accende o lo
spegne; con il mouse sulla barra compaiono anche quelli spenti (`bar.indicators.peek`) e `bar.indicators.alwaysShow` li tiene sempre
visibili; `bar.indicators.items` sceglie quali e in che ordine. In una zona centrale il gruppo, allargandosi, sposta gli elementi
vicini: a sinistra o a destra no. Gli elementi singoli restano disponibili.
WindowLayout mostra la disposizione delle finestre del contenitore col focus (colonne, righe, schede, pila, flottante) e serve il
demone dati; il clic passa alla successiva, il clic destro alla precedente. Con una scorciatoia di Sway:
`bindsym $mod+Tab exec vela ipc call layout next` (anche `prev`, `set tabbed`, `status`).
Quelli che dipendono da hardware o servizi assenti (batteria, ventola, retroilluminazione, Bluetooth, VPN) si nascondono da soli.

Interazioni: rotellina su Volume (±2%), Mic, Brightness (±5%), Workspaces e Media; clic destro su Volume (muto) e Bluetooth
(on/off); clic su Clock (calendario; destro = formato alternativo), Weather (pannello; destro = aggiorna), Battery (pannello del
limite di carica, se supportato), PowerProfile (profilo successivo), Vpn (accendi/spegni), Mic (muto), Tray (attiva; destro = menu).
Passando il mouse compaiono i tooltip.

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
cambia al prossimo `swaymsg reload`). Il pacchetto installa cinque sfondi in `/usr/share/backgrounds/vela` (predefinito: `Vela-5.jpg`, nella sessione Vela). Vela scrive `~/.config/vela/sway.d/vela.conf`; perché valga anche dopo il
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

## Schermi

Pannello **Schermi** (menu › Sistema › Schermi, oppure `vela ipc call panel toggle display`): luminosità e luce notturna (Spazio),
modalità rapide (anche **Duplica**, se è installato `wl-mirror`) con più schermi collegati
(solo interno, solo esterni, estendi) e, per ogni schermo, risoluzione e scala con ←/→. Ogni modifica ha la conferma di 15 secondi
(Invio = mantieni, Esc = ripristina; senza conferma tutto torna come prima). Da script o da una scorciatoia di Sway:
`vela ipc call display mode internal|external|extend`, poi `keep` o `revert` (`status` mostra lo stato). La rotazione e la posizione
in numeri restano nelle Impostazioni, scheda Schermi.
Con due schermi accesi la riga **Disposizione** mostra una mappa: ←/→ sceglie lo schermo, Maiusc+frecce lo sposta a sinistra, a destra,
sopra o sotto l'altro (`vela ipc call display place <schermo> left|right|above|below`).

## Stampanti

Impostazioni → **Sfondo** → «Scegli un'immagine…»: griglia di miniature delle immagini di `~/Immagini/backgrounds`, `~/Pictures/backgrounds`, `/usr/share/backgrounds` e `/usr/share/vela/assets` (file da 60 kB in su, due livelli di cartelle); ←/→/↑/↓ e Invio, oppure clic. Scrive `sway.wallpaper.path`; il percorso a mano resta disponibile sotto.

Pannello **Utente** (ultimo elemento a destra della barra, icona dell'omino, `Win+U`, oppure `vela ipc call panel toggle user`): la foto è `~/.face` (se manca, l'iniziale
del nome), il nome completo è il campo GECOS dell'utente (`chfn`), altrimenti il nome di login. ↑/↓ scelgono, Invio attiva, I/L/S/E/R/P scelgono la riga
direttamente; Esci, Riavvia e Spegni chiedono una seconda pressione (Esc annulla). Spegni e riavvia chiudono prima le finestre in ordine (`session` in `shell.jsonc`).
Per toglierlo: `panels.user.enabled = false` e via `User` da `bar.modules.right`.

Pannello **Stampanti** (menu › Stampanti, oppure `vela ipc call panel toggle printers`): stampanti CUPS con stato (pronta, in stampa, ferma) e predefinita,
coda dei lavori. Invio imposta la predefinita (o annulla il lavoro), Spazio ferma/riprende la stampante, Canc annulla i lavori. Compare solo con gli
strumenti di CUPS installati (`lpstat`); con `cupsd` fermo il pannello lo dice. Fermare e riprendere le stampanti richiede il gruppo `lpadmin`
(CUPS autorizza per gruppo: Vela non gestisce password). In fondo si aggiungono stampanti: «Cerca stampanti» (`lpinfo`, la ricerca in rete richiede avahi) oppure «Aggiungi per indirizzo» (nome, IP o URI);
l'aggiunta è senza driver (IPP Everywhere). Maiusc+Canc rimuove la stampante, con conferma. Stampanti che richiedono PPD o filtri: `localhost:631`.
Da script: `vela ipc call printers status|scan|add <indirizzo>|remove <nome>`.

## Servizi

Pannello **Servizi** (menu › Servizi, oppure `vela ipc call panel toggle services`): stato (attivo, fermo, non abilitato) di un elenco di servizi runit
(`services.list` in `shell.jsonc`: NetworkManager, bluetoothd, cupsd, avahi, ...). Lo stato si legge senza privilegi (collegamento in `/var/service`
e processo con `pgrep`, perché `sv status` è riservato a root). Spazio avvia/ferma (su un servizio non abilitato lo abilita: runit lo avvia da solo in pochi secondi), R riavvia, E abilita/disabilita: l'azione si apre in un terminale
(`services.terminal`, di default `foot -e`) con `doas` (o `sudo`), che **chiede la password ogni volta**; Vela non la vede e non installa regole senza password.
Da script: `vela ipc call services status|run <azione> <servizio>`. Compare solo se esiste `/var/service`.

## OSD e notifiche

L'OSD di volume e luminosità (`osd.enabled`) compare a ogni cambio e sostituisce `wob`. Il server di
notifiche integrato (`notifications.enabled`, spento per default) sostituisce `dunst`: va attivato solo dopo
aver fermato dunst/mako, perché un solo programma alla volta può possedere `org.freedesktop.Notifications`.
Testo sempre semplice, le notifiche critiche restano finché non si chiudono. Le notifiche dello stesso mittente si raggruppano in
una scheda sola: titolo e testo dell'ultima, il contatore (`×3`) e i titoli delle due precedenti; quelle identiche si fondono nel
contatore. Il clic chiude tutto il gruppo, il passaggio del mouse ferma la scadenza e una nuova notifica del gruppo la fa ripartire.
Un timeout esplicito dell'app (per esempio `notify-send -t 3000`) è rispettato.
"Non disturbare" (`vela ipc call toggles dnd` o la voce nel menu) scarta quelle non critiche.

## Lingua

Vela è in italiano; i testi sono traducibili (D-028). `language` in `~/.config/vela/shell.jsonc` (es. `"en"`; vuoto = lingua
dell'ambiente, poi italiano). I cataloghi stanno in `i18n/<lingua>.json` (italiano → traduzione); i propri in
`~/.config/vela/i18n/<lingua>.json`. Una voce mancante o vuota mostra l'italiano. Per tradurre: `scripts/i18n-extract --update xx`
crea il catalogo con tutte le chiavi, poi si riempiono i valori.

## Meteo

Il clic sull'icona del meteo apre il pannello con le condizioni attuali, le prossime 24 ore e i prossimi giorni (dati di yr.no); il clic destro aggiorna.
Serve la località in `weather.latitude` e `weather.longitude`.

## Calendario

Il clic sull'orologio apre il calendario del mese (numeri di settimana, ←/→ giorno, PagSu/PagGiù mese, T oggi); il clic destro cambia il formato
dell'orologio. Anche con `vela ipc call panel toggle calendar`. Per ora senza eventi.

## Layout di tastiera e aggiornamenti

Due elementi di barra che compaiono solo quando servono. **KeyboardLayout**: se in Sway è configurato più di un layout (`xkb_layout it,us`)
mostra la sigla del layout attivo; il clic passa al successivo (anche `vela ipc call keyboard next|prev`). **Updates**: con aggiornamenti
disponibili mostra il numero; il clic lancia l'aggiornamento in un terminale (`updates.command`). Il conteggio legge l'indice locale di xbps
(`xbps-install -un`): si aggiorna dopo una sincronizzazione (`xbps-install -S`), che Vela non fa da sé.

## Limite di carica della batteria

Sui portatili che lo permettono, il clic sull'icona della batteria apre un pannello con l'interruttore del limite di carica e
"Carica al 100% una volta" (poi il limite torna da solo). Stesse azioni nelle Impostazioni › Batteria. Su un PC senza questa funzione non compare nulla.
Serve la parte di sistema (helper di root in Rust, regola polkit per il gruppo `wheel`, regola udev): `make` come utente (serve `cargo`), poi `doas make install-system`. Senza l'helper installato la funzione resta nascosta. `make test` esegue i test dell'helper e del demone.
Funziona con le soglie regolabili (ThinkPad, 75/80) e con il limite fisso del firmware (IdeaPad, `charge_types`).

## Demone dati (in sviluppo)

`vela-daemon` è un piccolo programma Rust (solo libreria standard) che Vela avvia come processo figlio e che le manda, come righe JSON su stdout, lo stato di sistema raccolto da moduli. È di sola lettura: non esegue comandi, non scrive file, non apre socket. Dopo un'azione dell'utente (o `vela ipc call toggles refresh`) si ricontrolla comunque subito. Se manca, se muore o se smette di rispondere (15 s senza segnali), Vela lo rilancia e nel frattempo i servizi usano i loro controlli periodici. Si compila con `make` e `make install` lo mette in `/usr/libexec/vela/`; moduli: `night` (luce notturna, al posto di `pgrep gammastep`) e `sway` (input, layout di tastiera e touchpad dagli eventi di Sway, al posto di `swaymsg get_inputs` periodico). Configurazione: `daemon.enabled`, `daemon.command`, `daemon.modules`. Diagnostica: `vela ipc call daemon status` e `vela-daemon --once --modules …`.

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
