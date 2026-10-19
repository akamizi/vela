# Installazione di Vela. Uso: make install [PREFIX=/usr] [DESTDIR=...]
# Il QML e i default stanno insieme in $(PREFIX)/share/vela (la shell cerca i default in ../config/defaults).
PREFIX ?= /usr
DESTDIR ?=
SHARE = $(DESTDIR)$(PREFIX)/share
LIBEXEC = $(PREFIX)/libexec

# Parte privilegiata (D-032): helper delle soglie di carica, regola polkit e regola udev. Serve root: `doas make install-system`.
install-system:
	install -Dm755 helpers/battery-limit $(DESTDIR)$(LIBEXEC)/vela/battery-limit
	sed 's|@LIBEXEC@|$(LIBEXEC)|' helpers/org.vela.battery-limit.policy > helpers/.policy.tmp
	install -Dm644 helpers/.policy.tmp $(SHARE)/polkit-1/actions/org.vela.battery-limit.policy
	rm -f helpers/.policy.tmp
	install -Dm644 helpers/50-vela-battery-limit.rules $(SHARE)/polkit-1/rules.d/50-vela-battery-limit.rules
	sed 's|@LIBEXEC@|$(LIBEXEC)|' helpers/99-vela-battery-limit.rules > helpers/.udev.tmp
	install -Dm644 helpers/.udev.tmp $(DESTDIR)$(PREFIX:/usr=/usr)/lib/udev/rules.d/99-vela-battery-limit.rules
	rm -f helpers/.udev.tmp

install: install-system
	install -Dm644 helpers/battery-limit $(SHARE)/vela/helpers/battery-limit
	install -Dm755 scripts/vela $(DESTDIR)$(PREFIX)/bin/vela
	find shell config/defaults i18n -type f -exec install -Dm644 {} $(SHARE)/vela/{} \;
	find config/user.example -type f -exec install -Dm644 {} $(SHARE)/doc/vela/{} \;
	install -Dm644 README.md THIRD-PARTY.md -t $(SHARE)/doc/vela
	install -Dm644 VERSION $(SHARE)/vela/VERSION
	install -Dm644 assets/logo.svg $(SHARE)/vela/assets/logo.svg
	install -Dm644 LICENSE $(SHARE)/licenses/vela/LICENSE

.PHONY: install install-system
