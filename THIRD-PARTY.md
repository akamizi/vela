# Codice di terze parti

Vela è distribuita con licenza EUPL-1.2 (vedi `LICENSE`).

Al momento non è incluso codice di terze parti. Quando si copia codice da altri
progetti (per esempio Omarchy, licenza MIT, Copyright David Heinemeier Hansson),
va elencato qui con: file di destinazione, progetto e commit di origine, licenza
e testo dell'avviso di copyright, e va mantenuto l'avviso nel file copiato.

Dipendenze a runtime (non incorporate): Quickshell (LGPL-3.0), Qt 6.

Dati di terzi distribuiti in un pacchetto separato (non fanno parte di `vela`): `fluent-icon-theme` (template in
`packaging/void/fluent-icon-theme`) installa il tema icone Fluent di vinceliuice, GPL-3.0, derivato da Numix-circle, Papirus e
Paper (CC-BY-SA-4.0); è compilato dai sorgenti originali (https://github.com/vinceliuice/Fluent-icon-theme, tag 2026-07-27) e porta
con sé `COPYING` e `AUTHORS`. Vela lo usa a runtime come tema icone predefinito (D-061) e non ne incorpora nulla.
