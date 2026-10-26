# Tasti extra del T14, pannelli Musica e Subsonic: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vela offre i pannelli Musica e Subsonic (al posto degli script rofi di mizithink6), le scorciatoie `Win+Shift+M`, `Win+N`, `Win+,`, `Win+.`, e associa i tasti in più del T14 solo se esistono sul PC.

**Architecture:** Un arbitro `Player` (un solo mpv alla volta, estratto da `Radio.qml`) serve Radio, Musica e Subsonic. Un componente `BrowserPanel` (elenco filtrabile a due livelli, nello stile di `RadioPanel`) fa da base ai due pannelli nuovi. La logica pura (cartelle audio, file `env`, API Subsonic, lettura di `/proc/bus/input/devices`) sta in librerie JS `.pragma library` provate con node; i pezzi QML si provano in un'istanza di prova di Vela.

**Tech Stack:** Quickshell/QML (Qt 6), JS `.pragma library`, node (solo per i test JS), mpv, sway/labwc.

**Spec:** `docs/superpowers/specs/2026-10-26-tasti-extra-musica-subsonic-design.md` (leggerla insieme al piano).

## Global Constraints

- Licenza e intestazione di ogni file nuovo: `// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2`. Commenti e testi in italiano; i testi visibili passano da `I18n.tr("…")`; dopo ogni task con testi nuovi: `scripts/i18n-extract --update en`.
- Nessuna dipendenza nuova di pacchetto oltre a `mpv` (già `requires` della Radio). Niente `playerctl`: i tasti multimediali usano MPRIS tramite `Media` (scelta mia, vedi task 7).
- Un solo flusso mpv alla volta, condiviso da Radio, Musica e Subsonic; mai `pkill -f`; il processo è nostro (`setpriv --pdeathsig TERM` come in `Radio.qml`). Comando base del player: `Config.shell.radio.command`, se assente `["mpv","--no-video","--no-terminal"]`.
- Cartella Musica: dalla chiave `XDG_MUSIC_DIR` di `~/.config/user-dirs.dirs`; se manca o vale `$HOME`, prova `~/Musica` poi `~/Music`. Il pannello compare solo se la cartella esiste. Estensioni: mp3, flac, ogg, m4a, wav, opus (senza distinzione di maiuscole).
- Subsonic: file `~/.config/subsonic-mpv/env` con `SUBSONIC_URL`, `SUBSONIC_USER`, `SUBSONIC_PASS`; API versione `1.16.1`, client `vela`, `getAlbumList2` con `type=newest&size=100`, token = `md5(password + salt)`. La password non finisce mai in configurazione, log, notifiche o argomenti di processo; neppure il token negli argomenti di mpv (si passa un file di playlist con permessi 600 in `$XDG_RUNTIME_DIR`, cancellato alla fine). Il pannello compare se il file esiste; con permessi diversi da 600 o campi mancanti mostra l'errore e il comando `chmod 600 …`.
- Presenza di `~/Musica` e del file `env`: ricontrollata a ogni apertura del menu e dei pannelli, senza osservare i file.
- Registratore nativo (nuovo, senza audio): `wf-recorder` lanciato da Vela, area con `slurp`; file `rec-AAAAMMGG-HHMMSS.mp4` in `<XDG_VIDEOS_DIR>/Registrazioni` (se XDG manca: `~/Video`, `~/Videos`); VA-API (`-c h264_vaapi -d /dev/dri/renderD128`) solo se il dispositivo è leggibile e `vainfo --display drm --device …` elenca `VAProfileH264*VAEntrypointEncSlice` e `VAEntrypointVideoProc`, altrimenti `-c libx264 -p preset=veryfast`. Fermare = SIGINT a `wf-recorder` (il file va chiuso bene); se Vela muore, `setpriv --pdeathsig INT`. Dipendenza opzionale: `wf-recorder` (+ `slurp`, già usato per gli screenshot).
- Scorciatoie: `Win+Stamp` = registra/ferma lo schermo intero; `Win+<ritaglio>` (`$mod+XF86SelectiveScreenshot`) = registra/ferma un'area; lo stesso tasto (o l'altro) ferma una registrazione in corso, qualunque ne sia il tipo. `Win+M` resta Radio; `Win+Shift+M` = Musica; `Win+N` = Subsonic; `Win+,` = brano precedente; `Win+.` = brano successivo (tutti i PC, Sway e labwc). Tasto Copilot (`Win+Shift+F23`, `bindcode $mod+Shift+201`) = `vela files`.
- Prove con istanze di Vela separate: `unset I3SOCK` e impostare `I3SOCK` e `SWAYSOCK` sul socket di prova, controllando `/proc/<pid>/environ`; niente `pkill`/`toggles`/luminosità; non rilanciare a mano `vela` dopo `quickshell kill` (il crash handler lo rilancia). Per non fare rumore: player di prova con `--ao=null` tramite `radio.command` in una config di prova.

## Review Focus

- Nomi di file e cartelle con spazi, newline, accenti e `|` (lo script originale sceglie per nome: qui si lavora per percorso e per id).
- `XDG_MUSIC_DIR` che vale `"$HOME"` (voce non impostata) o punta a una cartella inesistente: nessun pannello, nessun errore.
- Radio/Musica/Subsonic avviati uno sopra l'altro e arresto con Stop: nessuno stato `error` per un arresto voluto; Vela chiuso = mpv chiuso.
- File `env` con virgolette, commenti, righe vuote, CRLF, campo mancante, permessi 644; password con `$`, `"` e `&`.
- Subsonic: rete assente, `status: "failed"` (password errata), lista album vuota, due album con lo stesso nome, brani senza `track`.
- `/proc/bus/input/devices` illeggibile o con più tastiere; combinazione già assegnata dall'utente (config di Sway o `sway.jsonc`): quella dell'utente vince, nessun «Overwriting binding».
- Registrazione: `slurp` annullato con Esc (nessun file, nessun errore), seconda pressione mentre `slurp` è aperto, `wf-recorder` assente, file chiuso bene dopo SIGINT, Vela chiuso durante la registrazione.
- Esc nei pannelli a due livelli: cancella il filtro, poi torna alle cartelle/album, poi chiude.

---

## File Structure

- Crea `tests/js/run.mjs` — esegue i test delle librerie JS (carica i file `.pragma library` in `node:vm`); `tests/js/*.test.mjs`.
- Crea `shell/services/Player.qml` — arbitro del player; modifica `shell/services/Radio.qml` (usa `Player`), `shell/plugins/bar/widgets/RadioWidget.qml`.
- Crea `shell/core/musiclib.js`, `shell/services/Music.qml`, `shell/plugins/panels/MusicPanel.qml`.
- Crea `shell/ui/BrowserPanel.qml` — base dei pannelli a due livelli.
- Crea `shell/core/subsonic.js`, `shell/services/Subsonic.qml`, `shell/plugins/panels/SubsonicPanel.qml`.
- Crea `shell/core/reclib.js`, `shell/services/Recorder.qml`; modifica `shell/services/Toggles.qml`.
- Crea `shell/core/hwkeys.js`, `shell/services/HardwareKeys.qml`; modifica `shell/services/SwayBackend.qml`, `shell/plugins/panels/ShortcutsPanel.qml`, `shell/core/shortcuts.js`.
- Modifica `shell/shell.qml`, `shell/services/MenuModel.qml`, `config/defaults/menu.jsonc`, `config/defaults/shell.jsonc`, `session/sway-config`, `session/labwc/rc.xml`, `Makefile`, `i18n/en.json`, `docs/MANUAL.md`, `docs/CHANGELOG.md`.

---

### Task 1: Banco di prova per le librerie JS

**Files:**
- Create: `tests/js/run.mjs`, `tests/js/smoke.test.mjs`
- Modify: `Makefile` (target `test-js`, aggiunto a `test`)

**Interfaces:**
- Produces: `load(relPath: string, globals?: object): object` esportata da `tests/js/run.mjs` — legge un file di `shell/core/`, toglie le righe `.pragma …` e `.import …`, lo esegue in `node:vm` e restituisce l'oggetto con le funzioni e le `var` dichiarate. I test sono file `tests/js/*.test.mjs` che importano `load` e usano `node:assert`.

- [ ] **Step 1: Test di fumo** `tests/js/smoke.test.mjs`: carica `shell/core/swayconf.js` e verifica `normalize("$mod+Shift+e", {"$mod":"Mod4"}) === "shift+super+e"`.
- [ ] **Step 2:** `node tests/js/run.mjs` — atteso: fallisce (manca `load`).
- [ ] **Step 3:** Implementare `run.mjs`: esporta `load`, e quando eseguito come programma lancia tutti i `*.test.mjs` della cartella (un processo per file) e termina con codice ≠ 0 se uno fallisce. Per `.import "swayconf.js" as SwayConf` (usato da `shortcuts.js`) `load` risolve l'import caricando il file indicato e mettendolo come globale `SwayConf`.
- [ ] **Step 4:** `node tests/js/run.mjs` — atteso: `ok smoke`, codice 0. `make test-js` fa lo stesso (`test:` dipende da `test-js` solo se `node` è presente).
- [ ] **Step 5: Commit** — `git add tests Makefile && git commit -m "Banco di prova node per le librerie JS"`.

---

### Task 2: Arbitro `Player` e Radio sopra di esso

**Files:**
- Create: `shell/services/Player.qml`
- Modify: `shell/services/Radio.qml`, `shell/plugins/bar/widgets/RadioWidget.qml`, `shell/shell.qml` (handler IPC `player`)

**Interfaces:**
- Produces (singleton `Player`): `property string state` (`"stopped"|"starting"|"playing"|"error"`), `property string kind` (`""|"radio"|"music"|"subsonic"`), `property string name`, `property string key` (identifica ciò che suona: URL, percorso, id), `property string error`, `readonly property bool playing` (starting o playing), `function play(kind: string, name: string, key: string, args: var): void` (`args` = argomenti dopo il comando base, es. `["--", url]`; ferma l'eventuale flusso in corso e avvia il nuovo), `function stop(): void`, `signal exited(kind: string, code: int, wanted: bool)`.
- Consumes: `Config.shell.radio.command`, `I18n.tr`.
- Radio mantiene la sua API (`stations`, `state`, `name`, `url`, `error`, `playing`, `play(station)`, `stop()`, `toggle(station)`), ora risposte da `Player` quando `Player.kind === "radio"` (altrimenti `state:"stopped"`, `name:""`, `url:""`).

- [ ] **Step 1:** Spostare in `Player.qml` il `Process`, il timer di conferma (3 s) e la logica pending/stopping di `Radio.qml` (stessi stati e stesso `setpriv --pdeathsig`), generalizzando `start()` a `play(kind,name,key,args)`. L'uscita con `stopping` vero non è un errore.
- [ ] **Step 2:** Riscrivere `Radio.qml` come strato sottile: proprietà derivate da `Player` e `play(station)` = `Player.play("radio", station.name, station.url, ["--", station.url])`. `validUrl` e `stations` restano.
- [ ] **Step 3:** `RadioWidget.qml`: visibile se `Player.state !== "stopped"`; mostra `Player.name`; icona della Radio per `kind==="radio"`, `Icons.music` per gli altri (aggiungere `music` in `shell/core/icons.js`: glifo `0xF075A`); clic = pannello del `kind` in corso (`Runtime.togglePanel(Player.kind)` se in `MenuModel.availablePanels`), clic destro = `Player.stop()`.
- [ ] **Step 4:** IPC: `IpcHandler { target: "player"; function stop(): void }` in `shell.qml`; `radio stop/play` restano.
- [ ] **Step 5 (prova, istanza separata):** con `radio.command = ["mpv","--no-video","--no-terminal","--ao=null"]` e una stazione di prova locale (file audio breve in loop): avviare, verificare `state` `starting` → `playing` dopo 3 s (`vela ipc call` o log), `radio stop` → `stopped` senza `error`, avviare due stazioni di fila → una sola istanza mpv (`pgrep -c -f ao=null` = 1). Atteso: tutto vero; il pannello Radio e il widget funzionano come prima.
- [ ] **Step 6: Commit** — `git commit -m "Player: un solo mpv per Radio, Musica e Subsonic"`.

---

### Task 3: Libreria `musiclib.js`

**Files:**
- Create: `shell/core/userdirs.js`, `shell/core/musiclib.js`, `tests/js/musiclib.test.mjs`

**Interfaces:**
- Produces (`userdirs.js`): `userDir(text: string, home: string, key: string): string` (valore di `key` in `user-dirs.dirs`, es. `"XDG_MUSIC_DIR"`, con `$HOME` espanso; `""` se manca o vale `home`).
- Produces (`musiclib.js`, importa `userdirs.js`): `musicDirCandidates(userDirsText: string, home: string): string[]` (prima quello di XDG_MUSIC_DIR, poi `home+"/Musica"`, `home+"/Music"`, senza doppioni), `isAudio(name: string): boolean`, `groupFolders(paths: string[], root: string): [{rel: string, path: string, files: [{name: string, path: string}]}]` (solo cartelle con audio, ordinate senza distinzione di maiuscole su `rel`, file ordinati per nome; `rel` relativo a `root`, `"."`→ `""` se i file sono nella radice, mostrato come nome della radice dal chiamante).

- [ ] **Step 1: Test** (`musiclib.test.mjs`): `userDir('XDG_MUSIC_DIR="$HOME/Musica"\n', "/home/u", "XDG_MUSIC_DIR") === "/home/u/Musica"`; con `"$HOME/"` → `""`; con `"# vuoto"` → `""`; `XDG_VIDEOS_DIR` letto con la sua chiave; `musicDirCandidates` con voce XDG = `/home/u/Música` elenca prima quella e poi `Musica`, `Music`; `isAudio("A.FLAC")` vero, `isAudio("a.txt")` e `isAudio("mp3")` falsi; `groupFolders(["/m/Rock/b b.mp3","/m/Rock/a|a.flac","/m/jazz/x.opus"], "/m")` → cartelle `["jazz","Rock"]`, file di Rock `["a|a.flac","b b.mp3"]`, `path` interi invariati.
- [ ] **Step 2:** `node tests/js/run.mjs` — atteso: FAIL.
- [ ] **Step 3:** Implementare le funzioni (nessuno shell, solo stringhe).
- [ ] **Step 4:** `node tests/js/run.mjs` — atteso: PASS.
- [ ] **Step 5: Commit** — `git commit -m "musiclib: cartella Musica XDG e raggruppamento dei file audio"`.

---

### Task 4: Componente `BrowserPanel`

**Files:**
- Create: `shell/ui/BrowserPanel.qml`

**Interfaces:**
- Produces: `BrowserPanel` (basato su `PanelHost`, stesse misure e tastiera di `RadioPanel`): proprietà `name`, `icon`, `title`, `meta`, `detail`, `iconColor`, `rows` (`[{kind:"header"|"item"|"message"|"stop", label, sub?, key, selected?}]`), `canGoBack: bool`, `footerHint: string`; segnali `activated(row)`, `back()`, `opened()`; la ricerca è interna (`query`, filtro applicato dal chiamante tramite `onQueryChanged`/proprietà `query` letta). Esc: se `query !== ""` la cancella; altrimenti se `canGoBack` emette `back()`; altrimenti `Runtime.closePanel()`. Backspace a filtro vuoto e `canGoBack` → `back()`.
- Consumes: `PanelHost`, `PanelHero`, `PanelRow`, `PanelSectionHeader`, `PanelSeparator`, `ToggleSwitch`, `Player`.

- [ ] **Step 1:** Estrarre da `RadioPanel.qml` (da non toccare) struttura, selezione (`select/move/restoreSelection`), tastiera e delegate, parametrizzando righe e azioni come sopra. Il toggle nell'hero ferma `Player.stop()` se `Player.playing`.
- [ ] **Step 2 (prova):** verrà esercitato dal Task 5; qui basta `qs` che carichi `shell.qml` senza errori QML con un pannello di prova che istanzia `BrowserPanel`. Atteso: nessun errore nel log di Quickshell.
- [ ] **Step 3: Commit** — `git commit -m "BrowserPanel: base dei pannelli a due livelli"`.

---

### Task 5: Pannello Musica e `Win+Shift+M`

**Files:**
- Create: `shell/services/Music.qml`, `shell/plugins/panels/MusicPanel.qml`
- Modify: `shell/shell.qml` (Loader + `IpcHandler` `music` con `stop`), `shell/services/MenuModel.qml` (`implementedPanels` + `usable()`: `target === "music" && !Music.available` → false; `Music.refresh()` chiamata da `Runtime.openMenu` e all'apertura del pannello), `config/defaults/shell.jsonc` (`panels.music.enabled: true`), `config/defaults/menu.jsonc` (voce `music`, label «Musica», `requires: ["mpv"]`, dopo Radio), `shell/core/shortcuts.js` (`panelNames()`: `music: tr("Musica")`, `subsonic: "Subsonic"`), `session/sway-config` (`bindsym $mod+Shift+m exec vela ipc call panel toggle music`), `session/labwc/rc.xml` (`W-S-m`)

**Interfaces:**
- Consumes: `musiclib.musicDirCandidates/groupFolders/isAudio`, `Player.play`, `BrowserPanel`.
- Produces (singleton `Music`): `property bool available`, `property string root`, `property var folders` (risultato di `groupFolders`), `property bool scanning`, `function refresh(): void` (rilegge `user-dirs.dirs` con `FileView`, sceglie il primo candidato che esiste con `test -d`, lancia `find <root> -type f -print0` con un `Process` senza shell e filtra con `isAudio`), `function playFolder(f): void`, `function playFile(f, folder): void`. Avvio: `Player.play("music", nome, percorso, ["--", ...percorsi])`; notifica di errore se `Player.exited` con codice ≠ 0 e non voluto: `Quickshell.execDetached(["notify-send","-a","Vela","-u","critical",…])`.

- [ ] **Step 1:** Servizio e pannello. Livello 1: cartelle (`label` = `rel`, la radice come «Musica»); livello 2: voce «▶ Tutta la cartella» e i brani; `canGoBack` al livello 2; stop come nella Radio. Elenco filtrabile; messaggio «Nessun brano trovato» se vuoto.
- [ ] **Step 2:** Registrazioni elencate sopra (loader, menu, config, scorciatoie Sway e labwc, nome del pannello nel pannello Scorciatoie).
- [ ] **Step 3 (prova, istanza separata):** `HOME` di prova con `Música/` contenente `a b/uno.mp3`, `x|y/due.flac`, `note.txt`, e `user-dirs.dirs` con `XDG_MUSIC_DIR="$HOME/Música"`. Verificare: voce di menu e `panel toggle music` presenti; senza la cartella la voce sparisce alla riapertura del menu; Invio su una cartella apre il livello 2, Esc torna indietro, «Tutta la cartella» accoda tutti i brani (un mpv, argomenti = percorsi); avviare la Radio ferma la musica. `XDG_MUSIC_DIR="$HOME"` → pannello assente.
- [ ] **Step 4:** `scripts/i18n-extract --update en`; **Commit** — `git commit -m "Pannello Musica (Win+Shift+M)"`.

---

### Task 6: Libreria `subsonic.js`

**Files:**
- Create: `shell/core/subsonic.js`, `tests/js/subsonic.test.mjs`

**Interfaces:**
- Produces: `parseEnv(text: string): {url, user, pass, missing: string[]}` (righe `CHIAVE=valore`, valori anche tra virgolette singole o doppie, commenti `#`, righe vuote e CRLF ignorati; nessuna espansione di shell; `url` senza `/` finale), `validUrl(u: string): boolean` (solo `http(s)://`), `authQuery(user: string, pass: string, salt: string, md5: function): string` (`u=…&t=…&s=…&v=1.16.1&c=vela&f=json`, valori codificati con `encodeURIComponent`), `albumListUrl(base, auth): string` (`/rest/getAlbumList2.view?type=newest&size=100&`+auth), `albumUrl(base, id, auth): string`, `streamUrl(base, id, auth): string`, `parseAlbums(json: object): {ok: bool, error: string, albums: [{id, label}]}` (`label` = `artista - nome`; `status !== "ok"` → `ok:false` con il messaggio dell'API), `parseSongs(json: object): {ok, error, songs: [{id, label, artist, title}]}` (`label` = `track. titolo`, senza `track` solo il titolo), `playlistText(entries: [{artist, title, url}]): string` (`#EXTM3U` e coppie `#EXTINF:-1,artista - titolo` / URL).

- [ ] **Step 1: Test** con valori del spec: `parseEnv('SUBSONIC_URL="https://s.example.org/"\r\nSUBSONIC_USER=u\n# x\nSUBSONIC_PASS=\'p$"&\'\n')` → url `https://s.example.org`, pass `p$"&`, `missing` vuoto; senza `SUBSONIC_PASS` → `missing:["SUBSONIC_PASS"]`; `validUrl("file:///x")` falso; `authQuery("u","pw","ab12", s => "MD5("+s+")")` contiene `t=MD5(pwab12)` e `s=ab12` e `v=1.16.1`; `parseAlbums({"subsonic-response":{status:"failed",error:{message:"Wrong username or password."}}})` → `ok:false` con quel messaggio; due album omonimi con id diversi restano due voci; `parseSongs` con brano senza `track` → `label` = titolo; `playlistText` inizia con `#EXTM3U\n`.
- [ ] **Step 2:** `node tests/js/run.mjs` — atteso: FAIL.
- [ ] **Step 3:** Implementare le funzioni (nessun accesso a rete o file).
- [ ] **Step 4:** `node tests/js/run.mjs` — atteso: PASS.
- [ ] **Step 5: Commit** — `git commit -m "subsonic: lettura del file env e dell'API"`.

---

### Task 7: Pannello Subsonic e `Win+N`

**Files:**
- Create: `shell/services/Subsonic.qml`, `shell/plugins/panels/SubsonicPanel.qml`
- Modify: `shell/shell.qml`, `shell/services/MenuModel.qml` (`implementedPanels`, `usable()` con `Subsonic.available`, `Subsonic.refresh()` come per Musica), `config/defaults/shell.jsonc`, `config/defaults/menu.jsonc` (voce `subsonic`, `requires: ["mpv"]`), `session/sway-config` (`bindsym $mod+n exec vela ipc call panel toggle subsonic`), `session/labwc/rc.xml` (`W-n`)

**Interfaces:**
- Consumes: `subsonic.js`, `Player.play`, `BrowserPanel`, `Qt.md5`, `XMLHttpRequest`.
- Produces (singleton `Subsonic`): `property bool available` (file `env` presente), `property string status` (`"ok"|"perms"|"incomplete"|"offline"|"error"|"loading"`), `property string error`, `property var albums`, `property var songs`, `function refresh(): void` (legge `env` con `FileView`, permessi con `stat -c %a`), `function loadAlbums(): void`, `function openAlbum(id, label): void`, `function playAlbum(): void`, `function playSong(song): void`. L'avvio scrive la playlist con `umask 077` in `$XDG_RUNTIME_DIR/vela-subsonic-<pid>.m3u` (anche per il singolo brano), chiama `Player.play("subsonic", label, id, ["--", file])` e cancella il file all'uscita di mpv, a Stop e all'avvio di Vela (`rm -f` dei file con quel prefisso).

- [ ] **Step 1:** Servizio e pannello: stato di errore nel pannello (con `chmod 600 <percorso>` se `perms`, elenco dei campi mancanti se `incomplete`, «Rete non raggiungibile» se `offline`, messaggio dell'API se `error`); livello 1 album, livello 2 «▶ Tutto l'album» e brani; Esc come nel Task 5.
- [ ] **Step 2:** Registrazioni elencate sopra.
- [ ] **Step 3 (prova):** server Subsonic finto locale (script Python di prova nella cartella scratch che risponde a `getAlbumList2.view`/`getAlbum.view`/`stream.view` e verifica `t = md5(pass+s)`), `HOME` di prova con `env` 600: elenco album, due album omonimi distinti, riproduzione di un brano e dell'album (un mpv, nessun URL né token in `ps` — `ps -eo args | grep -c "t="` = 0 — e playlist cancellata dopo Stop); `env` 644 → pannello con messaggio `chmod 600`; password sbagliata → messaggio dell'API; server spento → «Rete non raggiungibile»; senza `env` la voce di menu sparisce.
- [ ] **Step 4:** `scripts/i18n-extract --update en`; **Commit** — `git commit -m "Pannello Subsonic (Win+N)"`.

---

### Task 8: Registratore nativo (`Recorder`), `Win+Stamp`

**Files:**
- Create: `shell/core/reclib.js`, `tests/js/reclib.test.mjs`, `shell/services/Recorder.qml`
- Modify: `shell/services/Toggles.qml` (`recording` vero anche se `Recorder.state === "recording"`; `stopRecording()` usa `Recorder.stop()` quando `recordingStopCommand` è nullo), `shell/shell.qml` (`IpcHandler { target: "recorder"; toggle(mode: string); stop(); status() }`), `shell/core/shortcuts.js` (`describeVela`: target `recorder`, «Registra lo schermo» / «Registra un'area» / «Ferma la registrazione»), `session/sway-config` (`bindsym $mod+Print exec vela ipc call recorder toggle screen`), `session/labwc/rc.xml` (`W-Print`), `config/defaults/menu.jsonc` (nessuna voce)

**Interfaces:**
- Produces (`reclib.js`): `fileName(d: Date): string` (`rec-AAAAMMGG-HHMMSS.mp4`), `vaapiOk(vainfoText: string): bool`, `recorderArgs(mode: "screen"|"area", geometry: string, encoder: "vaapi"|"software", file: string, render: string): string[]` (argomenti di `wf-recorder`: `-g <geometry>` solo per l'area, poi `-c h264_vaapi -d <render>` o `-c libx264 -p preset=veryfast`, poi `-f <file>`).
- Produces (singleton `Recorder`): `property string state` (`"idle"|"selecting"|"recording"|"error"`), `property string mode`, `property string file`, `property string error`, `function toggle(mode: string): void` (idle → `start`; selecting o recording → `stop`, qualunque sia il modo), `function start(mode): void`, `function stop(): void`. Notifiche con `notify-send -a Vela` all'avvio, al salvataggio (con il percorso) e in caso di errore; cartella creata se manca; `Player` non è coinvolto.
- Consumes: `userdirs.userDir` (task 3), `Toggles.recording`.

- [ ] **Step 1: Test** (`reclib.test.mjs`): `fileName(new Date(2026,9,26,14,5,9)) === "rec-20261026-140509.mp4"`; `vaapiOk` vero con un testo che contiene sia `VAProfileH264Main : VAEntrypointEncSlice` sia `VAEntrypointVideoProc`, falso se manca uno dei due o se il testo è vuoto; `recorderArgs("area","10,20 300x200","software","/v/a.mp4","/dev/dri/renderD128")` = `["-g","10,20 300x200","-c","libx264","-p","preset=veryfast","-f","/v/a.mp4"]`; `recorderArgs("screen","", "vaapi", "/v/a.mp4","/dev/dri/renderD128")` = `["-c","h264_vaapi","-d","/dev/dri/renderD128","-f","/v/a.mp4"]`.
- [ ] **Step 2:** `node tests/js/run.mjs` — atteso: FAIL.
- [ ] **Step 3:** Implementare `reclib.js`; `node tests/js/run.mjs` — atteso: PASS.
- [ ] **Step 4:** `Recorder.qml`: lo stato `selecting` dura quanto `slurp` (Esc = `idle`, senza errore); la sonda VA-API una volta sola, alla prima registrazione; `wf-recorder` è un `Process` di Vela avviato con `setpriv --pdeathsig INT`; `stop()` = `signal(2)` (SIGINT) e attesa dell'uscita (poi SIGTERM dopo 5 s); `state` torna `idle` all'uscita; codice ≠ 0 non voluto → `error` e notifica critica.
- [ ] **Step 5:** Collegare `Toggles` (l'indicatore REC della barra si accende e il clic lo ferma), IPC, scorciatoie e testi.
- [ ] **Step 6 (prova, istanza separata):** in un Sway headless con output virtuale (`WLR_BACKENDS=headless`): `recorder toggle screen` → file `.mp4` in una cartella Videos di prova con `HOME` di prova e `state=recording`, indicatore REC acceso; `recorder toggle area` mentre registra → ferma e il file è leggibile (`ffprobe` ok); con `slurp` annullato non resta nulla; senza `wf-recorder` (PATH ripulito) → errore con notifica e `state=error`. Se `wf-recorder` non gira nell'output headless, documentare la prova rimasta da fare su un PC con schermo vero (mizithink6) e non dichiarare la fase verificata.
- [ ] **Step 7:** `scripts/i18n-extract --update en`; **Commit** — `git commit -m "Registratore dello schermo e Win+Stamp"`.

---

### Task 9: `Win+,` e `Win+.` e tasti multimediali via MPRIS

**Files:**
- Modify: `shell/shell.qml` (`IpcHandler { target: "media"; next(); previous(); playPause() }` su `Media.player`), `session/sway-config`, `session/labwc/rc.xml`, `shell/core/shortcuts.js` (descrizioni `vela ipc call media …`: «Brano successivo / precedente / Riproduci-pausa», gruppo «Schermo e audio»)

**Interfaces:**
- Produces: `vela ipc call media next|previous|playPause` — chiama `Media.player.next()/previous()/togglePlaying()` se `Media.available` e il player lo consente (`canGoNext`, `canGoPrevious`, `canTogglePlaying`), altrimenti non fa nulla.

- [ ] **Step 1:** Handler IPC e voci in `describeVela` (`target === "media"`).
- [ ] **Step 2:** `bindsym $mod+comma exec vela ipc call media previous`, `bindsym $mod+period exec vela ipc call media next` in `session/sway-config`; `W-comma`/`W-period` in `rc.xml`.
- [ ] **Step 3 (prova):** con mpv avviato da Vela (Radio di prova locale) e il plugin `mpv-mpris` installato (`~/.config/mpv/scripts/mpris.so`), `vela ipc call media playPause` mette in pausa e riprende; senza player attivo non succede nulla e non ci sono errori nel log.
- [ ] **Step 4:** `scripts/i18n-extract --update en`; **Commit** — `git commit -m "Win+, e Win+.: brano precedente e successivo via MPRIS"`.

---

### Task 10: Libreria `hwkeys.js`

**Files:**
- Create: `shell/core/hwkeys.js`, `tests/js/hwkeys.test.mjs`

**Interfaces:**
- Produces: `keyCodes(devicesText: string): {[evdevCode: number]: true}` (unisce le bitmask `B: KEY=` di tutti i dispositivi di `/proc/bus/input/devices`; parole esadecimali da 64 bit separate da spazi, la più significativa per prima), `hardwareBindings(codes): [{combo: string, command: string, description: string}]`, con questa tabella (codici evdev):
  - 164 `KEY_PLAYPAUSE` → `XF86AudioPlay` → `exec vela ipc call media playPause`;
  - 163 `KEY_NEXTSONG` → `XF86AudioNext` → `… media next`; 165 `KEY_PREVIOUSSONG` → `XF86AudioPrev` → `… media previous`;
  - 364 `KEY_FAVORITES` → `XF86Favorites` → `exec vela files`;
  - 634 `KEY_SELECTIVE_SCREENSHOT` → `XF86SelectiveScreenshot` → `exec sh -c 'grim -g "$(slurp)" - | swappy -f -'` (stessa azione di `Stamp` in Vela; xkb dà a questo tasto il keysym `XF86SelectiveScreenshot`, quindi niente `bindcode 642`);
  - 634 anche con Win: `$mod+XF86SelectiveScreenshot` → `exec vela ipc call recorder toggle area` («Registra un'area»);
  - sempre, senza rilevamento (F23 è un tasto normale e non si può riconoscere): `$mod+Shift+201` (`bindcode`) → `exec vela files`, descrizione «Tasto Copilot». Il combo di questa voce è scritto `bindcode`-style: il consumatore la emette come `bindcode`.
  Le voci hanno `description` in italiano già passata da `tr`.

- [ ] **Step 1: Test:** testo di prova con due tastiere, una con `B: KEY=` contenente il bit 164 (parola `…` che lo contenga — costruirla nel test a partire dal codice) e 634; `keyCodes` li riporta; `hardwareBindings({})` = solo la voce Copilot; `hardwareBindings` con 164+163+165 contiene le tre `XF86Audio*`; testo vuoto o spazzatura → `{}` senza eccezioni.
- [ ] **Step 2:** `node tests/js/run.mjs` — atteso: FAIL.
- [ ] **Step 3:** Implementare (usare `BigInt` non disponibile in JS di QML? verificare: se `BigInt` manca in Qt 6.x del sistema, scorrere le parole esadecimali a gruppi di 4 cifre senza `BigInt`).
- [ ] **Step 4:** `node tests/js/run.mjs` — atteso: PASS.
- [ ] **Step 5: Commit** — `git commit -m "hwkeys: tasti in più riconosciuti da /proc/bus/input/devices"`.

---

### Task 11: Tasti in più su Sway (rilevamento, file generato, pannello Scorciatoie)

**Files:**
- Create: `shell/services/HardwareKeys.qml`
- Modify: `shell/services/SwayBackend.qml` (`syncNow`, `inputWallpaperCommands`), `shell/plugins/panels/ShortcutsPanel.qml`, `shell/core/shortcuts.js` (nomi: `xf86audioplay`→«Riproduci», `xf86audionext`/`xf86audioprev`→«Avanti»/«Indietro», `xf86favorites`→«Preferiti», `xf86selectivescreenshot`→«Ritaglio»)

**Interfaces:**
- Produces (singleton `HardwareKeys`): `readonly property var bindings` (`hardwareBindings(keyCodes(testo))`), `function refresh(): void` (legge `/proc/bus/input/devices` con `FileView`, `printErrors:false`; illeggibile → solo Copilot). In `SwayBackend`: `function hardwareCommands(): string[]` — righe `bindsym --locked XF86… exec …` (media e schermo come nelle scorciatoie di sistema di Vela, `--locked` per i tasti multimediali) e `bindcode $mod+Shift+201 …`, **escluse** le combinazioni già presenti in `userConfig.binds` o in `Config.sway.keybindings` (confronto con `SwayConf.normalize`, in modo che la riga dell'utente vinca e non compaia «Overwriting binding»).
- Consumes: `hwkeys.js`, `SwayConf.normalize`.

- [ ] **Step 1:** `HardwareKeys.qml` e `hardwareCommands()`; aggiungere i comandi a `live` in `syncNow()` prima delle scorciatoie dell'utente (e a `appliedBinds` così `unbindsym` funziona), quindi nel file `vela.conf`. Solo se `active` (Sway).
- [ ] **Step 2:** `ShortcutsPanel.qml` passa a `Shortcuts.build` anche le voci di `HardwareKeys.bindings` (in `own`, dopo quelle dell'utente) così compaiono nell'elenco con i nomi dei tasti.
- [ ] **Step 3 (prova, istanza separata):** con `/proc/bus/input/devices` sostituito da un file di prova (proprietà `path` di prova via variabile d'ambiente `VELA_INPUT_DEVICES`, usata solo se impostata): senza i bit → `vela.conf` contiene solo la riga Copilot; con 164/163/165/364/634 → le righe corrispondenti; con un `bindsym XF86Favorites exec x` nel config di Sway di prova → quella riga non è generata. `swaymsg -t get_binding_state` / ricarica senza swaynag di «Overwriting».
- [ ] **Step 4:** `scripts/i18n-extract --update en`; **Commit** — `git commit -m "Tasti in più del T14 rilevati e associati su Sway"`.

---

### Task 12: labwc, documentazione e pc-configs

**Files:**
- Modify: `session/labwc/rc.xml`, `docs/MANUAL.md`, `docs/CHANGELOG.md`, `VERSION` (solo se il rilascio è deciso con l'utente), `../DECISIONI.md` (fuori da git: nuova voce D-056, con data 2026-10-26), `../PIANO.md`
- Modify (altro repo): `pc-configs/topics/vela/README.md`, `pc-configs/hosts/mizithink6.md`

- [ ] **Step 1:** `rc.xml`: aggiungere, accanto ai tasti multimediali esistenti, `XF86AudioPlay/Next/Prev` (`allowWhenLocked`, comandi `media`), `XF86Favorites` (`vela files`), `XF86SelectiveScreenshot` (come `Print`), `W-XF86SelectiveScreenshot` (`recorder toggle area`). Il tasto Copilot su labwc **non** si associa (labwc non ha `bindcode`; su mizithink6 va verificato con `wev`): annotarlo in `rc.xml`, nel manuale e in D-056. Scelta mia: su labwc i tasti sono statici (nessun rilevamento), perché `rc.xml` è del pacchetto e labwc non ha include.
- [ ] **Step 2:** Manuale: sezioni «Musica», «Subsonic» (formato del file `env`, permessi), tasti in più, scorciatoie nuove; CHANGELOG (voce di versione); D-056 con le motivazioni (arbitro unico, nessun `playerctl`, tasti statici su labwc).
- [ ] **Step 3:** Verifica finale: `node tests/js/run.mjs`; `scripts/i18n-extract --check en` senza voci mancanti; `sway -C -c session/sway-config` senza errori (con `grep -n 'mod+Shift+m\|mod+n\|mod+comma\|mod+period' session/sway-config` = una riga ciascuna, nessun doppione); avvio di un'istanza di prova della sessione labwc per controllare che `rc.xml` sia XML valido (`xmllint --noout session/labwc/rc.xml`).
- [ ] **Step 4:** pc-configs: topic `vela` (tasti nuovi, dipendenze: `mpv-mpris` per i tasti multimediali, file `env` di Subsonic) e scheda di mizithink6 («Vela da installare/provare»); `git pull --rebase` prima, commit proposto all'utente (non automatico).
- [ ] **Step 5: Commit** — `git commit -m "labwc, manuale e decisione D-056 per tasti extra, Musica e Subsonic"`.

---

## Self-review (fatta)

- **Copertura del design:** obiettivo 1 → task 10–12; obiettivo 2 → task 2–8; obiettivo 3 → task 5, 7, 8; obiettivo 4 → task 5, 7, 8, 9, 12 (labwc) e `I18n.tr`; cartella Musica multilingua → task 3, 5; controllo a ogni apertura → task 5, 7; permessi 600 e playlist → task 7; il registratore (senza audio, scelto dall'utente) è nel task 8; il tasto Copilot su labwc è omesso, dichiarato.
- **Scelte mie rispetto al design** (da controllare): niente `playerctl` ma IPC `media` su MPRIS; `Player` unico arbitro e `Radio` ridotta a strato sottile; `radio.command` come comando base di tutti i flussi; librerie JS provate con node (il repo non ha test QML); la variabile `VELA_INPUT_DEVICES` per provare i tasti.
- **Rischio principale:** il refactor di `Radio.qml` (task 2) tocca una funzione che oggi funziona: la prova del task 2 va ripetuta a fine lavoro.
