# Installazione del greeter di Vela (pacchetto vela-greeter, D-055). Uso: make install [PREFIX=/usr] [DESTDIR=...]
# Non installa nulla fuori da PREFIX: la configurazione di greetd (/etc/greetd/config.toml) si cambia a mano.
PREFIX ?= /usr
SHARE = $(DESTDIR)$(PREFIX)/share

install:
	install -Dm644 shell.qml $(SHARE)/vela-greeter/shell.qml
	install -Dm644 Greeter.qml $(SHARE)/vela-greeter/Greeter.qml
	install -Dm644 background.jpg $(SHARE)/vela-greeter/background.jpg
	install -Dm755 vela-greeter $(DESTDIR)$(PREFIX)/libexec/vela-greeter/vela-greeter
	install -Dm644 greetd-config.toml.example $(SHARE)/doc/vela-greeter/greetd-config.toml.example
	install -Dm644 README.md $(SHARE)/doc/vela-greeter/README.md
	install -Dm644 ../LICENSE $(SHARE)/licenses/vela-greeter/LICENSE
	install -Dm644 VERSION $(SHARE)/vela-greeter/VERSION

.PHONY: install
