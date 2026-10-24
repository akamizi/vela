# Greeter di Vela (D-055)

Schermata di accesso in Quickshell per **greetd**, nello stile di Vela. **Fase 1**: greeter minimo (utente, password, sessione) con sfondo e orologio.
Pacchetto separato da `vela` e **senza dipendenze reciproche**: colori, font e sfondo sono nel greeter, nessun file di Vela è richiesto (lo sfondo
predefinito `/usr/share/backgrounds/vela/Vela-5.jpg`, se manca resta il colore di fondo).

- `shell.qml`: finestra a schermo intero, da lanciare in un compositor minimo: `cage -s -- quickshell -p <cartella>` (candidati: `cage`, `labwc`).
- `Greeter.qml`: interfaccia e flusso con `Quickshell.Services.Greetd` (create_session → password → readyToLaunch → dissolvenza → launch).
  Tasti: Invio nel campo utente apre la sessione di accesso, Invio nella password la invia, Tab cambia campo, ↑/↓ nel campo password cambiano sessione.
  Dopo un errore riapre da sé la sessione (con una pausa di 300 ms: la risposta di greetd alla cancellazione che Quickshell invia da solo deve arrivare prima).
- Sessioni: elenco da `/usr/share/wayland-sessions/*.desktop` (`VELA_GREETER_SESSIONS` per le prove), escluse `Hidden`/`NoDisplay`; il comando si lancia con `sh -c`.
- Variabili per le prove: `VELA_GREETER_SESSIONS`, `VELA_GREETER_WALLPAPER`.

## Prove senza root e senza toccare greetd

`test/fake-greetd.py <socket> <log>` è un greetd finto (utente `mizi`, password `ok`) che parla il protocollo vero; `test/shell.qml` guida il greeter
(utente, password sbagliata, password giusta) senza simulare tasti. Il socket deve avere un percorso corto (limite di 108 caratteri): per esempio in `$XDG_RUNTIME_DIR`.
Quickshell non accetta moduli fuori dalla cartella della configurazione: per la prova si copiano `Greeter.qml` e `test/shell.qml` (senza la riga `import ".."`) in una cartella di prova.

## Stato

- Fatto e provato (Sway headless e `cage` headless, greetd finto): flusso completo con errore e riprova, lancio della sessione scelta, elenco sessioni, aspetto.
- **Non provato**: con il greetd vero (PAM, utente `_greeter`, VT), con tastiera e mouse veri, transizione verso la sessione (lo stacco nero), più schermi (oggi una sola finestra).
- **Mancano** (fase 2+): ricordo di ultimo utente e sessione, spegni/riavvia, tema condiviso opzionale con Vela, dissolvenza coordinata con la sessione, pacchetto `vela-greeter`, configurazione di greetd (`/etc/greetd/config.toml`, solo con conferma e copia di sicurezza; oggi usa `tuigreet`).
- Nel log di Quickshell compare «Received unexpected greetd response success»: è la risposta di greetd alla cancellazione che Quickshell invia da solo dopo un errore; è innocuo.
