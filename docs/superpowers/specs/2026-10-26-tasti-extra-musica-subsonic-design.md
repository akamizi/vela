# Tasti extra del T14, pannelli Musica e Subsonic

Data: 2026-10-26. Stato: in attesa di approvazione dell'utente.

## Perché

Vela deve poter girare su mizithink6 (ThinkPad T14 Gen 6), che ha tasti in più rispetto agli altri PC
e due script personali (`musica-mpv`, `subsonic-mpv`) legati a `Win+M`, `Win+Shift+M`, `Win+N`.
Riferimenti: `pc-configs/topics/sysmenu/varianti/mizithink6/` (config sway, README, `files/bin/`).
Le scorciatoie di Vela restano quelle valide: di mizithink6 si prendono solo i tasti in più e le tre
scorciatoie musicali. Stamp, volume, luminosità, `Win+Alt+Spazio` e il resto non si toccano.

## Obiettivi

1. Vela verifica se i tasti in più esistono sul PC e, solo in quel caso, li associa ai default di mizithink6.
2. Due pannelli nuovi, **Musica** e **Subsonic**, nello stile del pannello Radio, che sostituiscono gli script rofi.
3. Scorciatoie su tutti i PC: `Win+M` = Radio (invariato, sostituisce `radio-mpv`), `Win+Shift+M` = Musica, `Win+N` = Subsonic.
4. Funziona su Sway e su labwc; testi traducibili (D-028).

## Non obiettivi

- Nessuna gestione della libreria (tag, copertine, playlist salvate, ricerca full-text).
- Nessun player integrato: si lancia mpv come per la Radio.
- Non si portano su Vela le altre scorciatoie di mizithink6 (`Win+Alt+Spazio`, `Win+Shift+W`, sysmenu, rofi, ecc.).
- Anti-obiettivo: la password di Subsonic non finisce mai in `shell.jsonc`/`settings.jsonc`, nei log o nelle notifiche.

## Tasti in più (da mizithink6)

| Tasto | Su mizithink6 | Rilevamento |
|---|---|---|
| `XF86AudioPlay/Next/Prev` | playerctl play-pause/next/previous | capacità tasto dei dispositivi di input |
| `Win+,` / `Win+.` (keysym `comma`/`period`) | playerctl previous/next | nessuno: tasti normali, valgono su tutti i PC (deciso dall'utente) |
| `XF86Favorites` | Thunar (per Vela: il file manager predefinito, `vela files`) | KEY_FAVORITES |
| tasto «ritaglio» (keycode 642, evdev 634, `KEY_SELECTIVE_SCREENSHOT`) | screenshot di un'area; con Win registra un'area | KEY_SELECTIVE_SCREENSHOT |
| tasto Copilot (keycode 201, evdev 193 = F23; manda Win+Shift+F23) | rofi filebrowser (per Vela: `vela files`, mia ipotesi) | invio di F23 non rilevabile a priori: si associa sempre `Win+Shift+F23`, innocuo se il tasto manca |

- Rilevamento senza privilegi: lettura di `/proc/bus/input/devices` (bitmask `KEY=`) o equivalente.
- Dove si scrive: un file generato da Vela in `~/.config/vela/sway.d/` (Sway) e le voci equivalenti per labwc; non si
  modificano i file dell'utente e le righe dell'utente vincono. Le scorciatoie compaiono nel pannello Scorciatoie
  (`shortcuts.js` va aggiornato per i nuovi tasti: nomi di `XF86…`, `playerctl`, ecc.).
- Mia osservazione: in Sway un `bindsym` su un tasto inesistente è innocuo, quindi il rilevamento serve soprattutto per
  non mostrare scorciatoie inutili e per labwc; il builder valuti se basta il rilevamento o conviene anche un default statico.
- Gli screenshot usano gli strumenti di Vela (grim + slurp + swappy), non `cap-shot`/`cap-record`.
- **Registratore nativo (deciso dall'utente, senza audio):** Vela non sapeva avviare registrazioni (solo l'indicatore REC di un comando esterno). Si aggiunge un servizio `Recorder` (`wf-recorder` + `slurp`, VA-API se disponibile, altrimenti software; cartella Registrazioni nei Video XDG), con `Win+Stamp` = schermo intero e `Win+<ritaglio>` = area; lo stesso tasto ferma una registrazione in corso. L'indicatore REC della barra segue il servizio. `wf-recorder` è dipendenza opzionale.

## Pannello Musica

- Cartella: **la cartella Musica dell'utente secondo XDG** (`xdg-user-dir MUSIC` / `~/.config/user-dirs.dirs`), perciò vale in qualunque
  lingua (`~/Musica`, `~/Music`, …); se non risolta, prova `~/Musica` e `~/Music`. Il pannello compare solo se la cartella esiste (decisione dell'utente: controllo multilingua).
- Estensioni: mp3, flac, ogg, m4a, wav, opus (come lo script).
- Navigazione a due livelli come lo script: cartelle che contengono audio, poi brani; voce «Tutta la cartella»; voce Stop.
  Digitando si filtra; Esc torna indietro; Invio avvia; stesso comportamento di focus e tastiera della Radio.
- Riproduzione: processo mpv gestito da Vela (`--no-video --no-terminal`, `setpriv --pdeathsig`), un solo flusso alla volta,
  condiviso con la Radio e con Subsonic: avviarne uno ferma l'altro. Niente `pkill -f` come nello script.
- Notifica d'inizio e d'errore come nello script; il widget di barra mostra cosa suona (come Radio).
- Pannello `panel toggle music`, voce nel menu Sistema accanto a Radio, `requires: ["mpv"]`, scorciatoia `Win+Shift+M`.

## Pannello Subsonic

- Credenziali: `~/.config/subsonic-mpv/env` (`SUBSONIC_URL`, `SUBSONIC_USER`, `SUBSONIC_PASS`), lo stesso file dello script.
  Vela non lo scrive e rifiuta di usarlo se i permessi non sono 600 (mia scelta, da mostrare nel pannello). Il pannello compare
  solo se il file esiste.
- API: Subsonic 1.16.1 con token+salt (md5), come lo script; elenco degli ultimi 100 album, poi brani; «Tutto l'album»; Stop.
- Il token/URL di streaming non compaiono in notifiche, log o `ps` oltre a quanto serve a mpv (il builder valuta playlist temporanea con permessi 600 come nello script, o altro).
- Rete assente o errore dell'API: messaggio nel pannello, non una finestra vuota.
- Pannello `panel toggle subsonic`, voce di menu, `requires: ["mpv", "curl"]` (e quanto serve per md5), scorciatoia `Win+N`.

## Ordine di lavoro (fasi piccole)

1. Pannelli Musica e Subsonic con le tre scorciatoie e le voci di menu (indipendenti dall'hardware).
2. Rilevamento dei tasti in più e relativo file generato, con voci in Scorciatoie.
3. Aggiornare pc-configs (topic `vela` e scheda di mizithink6: Vela installato) e `DECISIONI.md`.

## Lasciato al builder

Struttura dei servizi QML (un servizio audio comune alla Radio o servizi separati con arbitro), formato del file di
configurazione, nomi dei campi in `shell.jsonc`, traduzioni, test, numero di versione.

## Da verificare sul sistema (non assumere)

- Il PC su cui si sviluppa è ideamizi, non mizithink6: i tasti si provano con eventi simulati o su mizithink6 con `wev`.
- Il keysym effettivo di KEY_SELECTIVE_SCREENSHOT in xkb (se manca, serve `bindcode 642`, come su mizithink6).

## Risposte al controllo del builder

Decisioni mie (da controllare):

- **Radio e player condiviso:** è accettabile toccare `Radio.qml` in modo minimo, quanto serve perché un solo flusso alla volta valga per Radio, Musica e Subsonic (arbitro comune). Il widget di barra è lo stesso e mostra ciò che suona.
- **Subsonic, elenco:** `getAlbumList2` con `type=newest`, `size=100`, come lo script (ora in pc-configs: `topics/sysmenu/varianti/mizithink6/files/bin/subsonic-mpv`; esempio di env nello stesso topic).
- **Subsonic, playlist temporanea:** file con permessi 600 in `$XDG_RUNTIME_DIR`, cancellato quando mpv termina, all'avvio di Vela e quando si ferma; l'URL con token non va in notifiche e log.
- **File `env` con permessi sbagliati o incompleto:** il pannello compare e mostra l'errore con il comando per correggere (`chmod 600 …`); non compare solo se il file manca.
- **Quando si controlla la presenza di Musica e del file `env`:** a ogni apertura del menu o del pannello, senza osservare i file.
- **labwc:** non esiste un include per le scorciatoie (`rc.xml` è installato dal pacchetto in `/usr/share/vela/labwc`, `~/.config/vela/labwc.d/*.sh` solo per script di avvio). La fase 2 per labwc usa `labwc.d` o un meccanismo equivalente che il builder sceglie; i tasti in più su Sway sono prioritari.
- **Registrazione dello schermo:** `Win+<ritaglio>` si lega solo se Vela ha già un'azione di registrazione dell'area (il builder verifica); altrimenti si omette.

Confermato dall'utente: il tasto Copilot (`Win+Shift+F23`) lancia `vela files`; `Win+,`/`Win+.` valgono su tutti i PC.
