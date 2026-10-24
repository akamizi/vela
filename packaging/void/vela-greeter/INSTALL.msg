vela-greeter è installato ma NON attivo: la configurazione di greetd non è stata toccata.
Per usarlo (come root):
  1. copia la configurazione attuale: cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
  2. metti in /etc/greetd/config.toml il contenuto di /usr/share/doc/vela-greeter/greetd-config.toml.example
  3. l'utente _greeter deve poter usare la scheda grafica: di solito basta  usermod -aG video _greeter
  4. riavvia greetd (o il PC). Se il login non appare, torna al terminale (Ctrl+Alt+F3) e ripristina la copia.
Impostazioni facoltative (layout tastiera, sfondo): /etc/vela-greeter.conf (vedi /usr/libexec/vela-greeter/vela-greeter).
