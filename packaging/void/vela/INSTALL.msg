Vela è installato. Il pacchetto non modifica i tuoi file né attiva servizi: restano da fare a mano
(guida completa: README, sezione «Primo avvio», in /usr/share/doc/vela).
 - Sway: aggiungi `exec vela` e le scorciatoie a ~/.config/sway/config, togli il blocco `bar { … }`
   e ferma Waybar, dunst, mako, wob.
 - Servizi runit, solo quelli che ti servono:
   doas ln -s /etc/sv/NetworkManager /var/service/   (anche bluetoothd, cupsd, avahi-daemon)
 - Gruppi (poi rifai il login): doas usermod -aG network,lpadmin,wheel $USER
