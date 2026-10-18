# Installazione di Vela. Uso: make install [PREFIX=/usr] [DESTDIR=...]
# Il QML e i default stanno insieme in $(PREFIX)/share/vela (la shell cerca i default in ../config/defaults).
PREFIX ?= /usr
DESTDIR ?=
SHARE = $(DESTDIR)$(PREFIX)/share

install:
	install -Dm755 scripts/vela $(DESTDIR)$(PREFIX)/bin/vela
	find shell config/defaults -type f -exec install -Dm644 {} $(SHARE)/vela/{} \;
	find config/user.example -type f -exec install -Dm644 {} $(SHARE)/doc/vela/{} \;
	install -Dm644 README.md THIRD-PARTY.md -t $(SHARE)/doc/vela
	install -Dm644 LICENSE $(SHARE)/licenses/vela/LICENSE

.PHONY: install
