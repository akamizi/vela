# Greeter di Vela (D-055)

Schermata di accesso in Quickshell per **greetd**, nello stile di Vela. **Fase 1**: greeter minimo (utente, password, sessione) con sfondo e orologio. **Fase 2**: ricordo di ultimo utente e sessione, spegni/riavvia, tema di Vela facoltativo.
Pacchetto separato da `vela` e **senza dipendenze reciproche**: colori, font e sfondo sono nel greeter, nessun file di Vela è richiesto (lo sfondo
predefinito `/usr/share/backgrounds/vela/Vela-5.jpg`, se manca resta il colore di fondo).

- `shell.qml`: finestra a schermo intero, da lanciare in un compositor minimo: `cage -s -- quickshell -p <cartella>` (candidati: `cage`, `labwc`).
- `Greeter.qml`: interfaccia e flusso con `Quickshell.Services.Greetd` (create_session → password → readyToLaunch → dissolvenza → launch).
  Tasti: Invio nel campo utente apre la sessione di accesso, Invio nella password la invia, Tab cambia campo, ↑/↓ nel campo password cambiano sessione.
  Dopo un errore riapre da sé la sessione (con una pausa di 300 ms: la risposta di greetd alla cancellazione che Quickshell invia da solo deve arrivare prima).
- Sessioni: elenco da `/usr/share/wayland-sessions/*.desktop` (`VELA_GREETER_SESSIONS` per le prove), escluse `Hidden`/`NoDisplay`; il comando si lancia con `sh -c`.
- **Ricordo** (fase 2): all'accesso scrive `{"user","session"}` in `/var/cache/vela-greeter/state.json` (cartella da creare e rendere scrivibile a `_greeter`: lo farà il pacchetto; se non si può scrivere, niente ricordo e nessun errore). All'avvio ripristina l'utente (apre subito la sessione di accesso, quindi la password si digita subito) e la sessione. Nessun dato sensibile.
- **Spegni/Riavvia** (fase 2): pulsanti in basso a destra e tasti F12/F11; il primo clic arma («Conferma?» per 4 s), il secondo esegue `loginctl poweroff` / `loginctl reboot` (`VELA_GREETER_POWEROFF`, `VELA_GREETER_REBOOT`). I permessi dipendono da elogind/polkit per l'utente `_greeter`: **da verificare con il sistema vero**.
- **Tema facoltativo** (fase 2): se esiste `/usr/share/vela/config/defaults/theme.jsonc` (installato da Vela) il greeter ne legge colori e carattere; altrimenti usa i suoi default. Non è una dipendenza e non legge `~/.config`.
- Variabili per le prove: `VELA_GREETER_SESSIONS`, `VELA_GREETER_WALLPAPER`, `VELA_GREETER_STATE`, `VELA_GREETER_THEME`, `VELA_GREETER_POWEROFF`, `VELA_GREETER_REBOOT`.

## Prove senza root e senza toccare greetd

`test/fake-greetd.py <socket> <log>` è un greetd finto (utente `mizi`, password `ok`) che parla il protocollo vero; `test/shell.qml` guida il greeter
(utente, password sbagliata, password giusta) senza simulare tasti. Il socket deve avere un percorso corto (limite di 108 caratteri): per esempio in `$XDG_RUNTIME_DIR`.
Quickshell non accetta moduli fuori dalla cartella della configurazione: per la prova si copiano `Greeter.qml` e `test/shell.qml` (senza la riga `import ".."`) in una cartella di prova.

## Stato

- Fatto e provato (Sway headless e `cage` headless, greetd finto): flusso completo con errore e riprova, lancio della sessione scelta, elenco sessioni, aspetto.
- **Non provato**: con il greetd vero (PAM, utente `_greeter`, VT), con tastiera e mouse veri, transizione verso la sessione (lo stacco nero), più schermi (oggi una sola finestra).
- Provato in più (fase 2, greetd finto): ricordo di utente e sessione tra due avvii, tema letto dal file (colore e carattere), spegni/riavvia con conferma (comando finto). Il ricordo scrive nel file di prova; la cartella vera non esiste ancora.
- **Mancano** (fase 3+): dissolvenza coordinata con la sessione, pacchetto `vela-greeter`, configurazione di greetd (`/etc/greetd/config.toml`, solo con conferma e copia di sicurezza; oggi usa `tuigreet`).
- Nel log di Quickshell compare «Received unexpected greetd response success»: è la risposta di greetd alla cancellazione che Quickshell invia da solo dopo un errore; è innocuo.
