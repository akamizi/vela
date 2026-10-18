# Vela

Shell minimale per Sway su Void Linux (barra, launcher, pannelli), basata su Quickshell.
Licenza: EUPL-1.2.

Stato: Fase 1 (scheletro, tema e configurazione a strati). Vedi `PIANO.md` nella cartella padre del progetto.

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
