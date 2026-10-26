# Installazione di Vela. Uso: make install [PREFIX=/usr] [DESTDIR=...]
# Il QML e i default stanno insieme in $(PREFIX)/share/vela (la shell cerca i default in ../config/defaults).
PREFIX ?= /usr
DESTDIR ?=
SHARE = $(DESTDIR)$(PREFIX)/share
LIBEXEC = $(PREFIX)/libexec

# Helper delle soglie di carica (Rust, solo libreria standard, D-038): si compila come utente con `make`.
HELPER_DIR = helpers/battery-limit
HELPER_BIN = $(HELPER_DIR)/target/release/battery-limit

DAEMON_DIR = daemon
DAEMON_BIN = $(DAEMON_DIR)/target/release/vela-daemon

all: helper daemon

daemon:
	cargo build --release --locked --manifest-path $(DAEMON_DIR)/Cargo.toml --target-dir $(DAEMON_DIR)/target

helper:
	cargo build --release --locked --manifest-path $(HELPER_DIR)/Cargo.toml --target-dir $(HELPER_DIR)/target

test: test-js test-sh
	cargo test --locked --manifest-path $(HELPER_DIR)/Cargo.toml --target-dir $(HELPER_DIR)/target
	cargo test --locked --manifest-path $(DAEMON_DIR)/Cargo.toml --target-dir $(DAEMON_DIR)/target

# Librerie JS della shell (shell/core/*.js): serve node.
test-js:
	@if command -v node >/dev/null; then node tests/js/run.mjs; else echo "node assente: test JS saltati"; fi

# Script di avvio (scripts/vela): serve sh e python3.
test-sh:
	@sh tests/sh/vela-wait-pipewire.sh

# Parte privilegiata (D-032): helper delle soglie di carica, regola polkit e regola udev.
# Serve root: `make` come utente, poi `doas make install-system` (installa il binario già compilato).
install-system:
	@test -x $(HELPER_BIN) || { echo "manca $(HELPER_BIN): esegui prima 'make' come utente" >&2; exit 1; }
	install -Dm755 $(HELPER_BIN) $(DESTDIR)$(LIBEXEC)/vela/battery-limit
	sed 's|@LIBEXEC@|$(LIBEXEC)|' helpers/org.vela.battery-limit.policy > helpers/.policy.tmp
	install -Dm644 helpers/.policy.tmp $(SHARE)/polkit-1/actions/org.vela.battery-limit.policy
	rm -f helpers/.policy.tmp
	install -Dm644 helpers/50-vela-battery-limit.rules $(SHARE)/polkit-1/rules.d/50-vela-battery-limit.rules
	sed 's|@LIBEXEC@|$(LIBEXEC)|' helpers/99-vela-battery-limit.rules > helpers/.udev.tmp
	install -Dm644 helpers/.udev.tmp $(DESTDIR)$(PREFIX:/usr=/usr)/lib/udev/rules.d/99-vela-battery-limit.rules
	rm -f helpers/.udev.tmp

install: install-system
	@test -x $(DAEMON_BIN) || { echo "manca $(DAEMON_BIN): esegui prima 'make' come utente" >&2; exit 1; }
	install -Dm755 $(DAEMON_BIN) $(DESTDIR)$(LIBEXEC)/vela/vela-daemon
	install -Dm755 scripts/vela $(DESTDIR)$(PREFIX)/bin/vela
	find shell config/defaults i18n -type f -exec install -Dm644 {} $(SHARE)/vela/{} \;
	find config/user.example -type f -exec install -Dm644 {} $(SHARE)/doc/vela/{} \;
	install -Dm644 README.md THIRD-PARTY.md docs/MANUAL.md docs/CHANGELOG.md -t $(SHARE)/doc/vela
	install -Dm644 VERSION $(SHARE)/vela/VERSION
	install -Dm644 assets/logo.svg $(SHARE)/vela/assets/logo.svg
	install -Dm644 wallpapers/*.jpg -t $(SHARE)/backgrounds/vela
	install -Dm644 LICENSE $(SHARE)/licenses/vela/LICENSE
	install -Dm755 session/vela-session $(DESTDIR)$(PREFIX)/bin/vela-session
	install -Dm755 session/session-init $(DESTDIR)$(LIBEXEC)/vela/session-init
	install -Dm644 session/sway-config $(SHARE)/vela/sway/config
	install -Dm644 session/portals.conf $(SHARE)/vela/portals.conf
	install -Dm644 session/vela.desktop $(SHARE)/wayland-sessions/vela.desktop
	install -Dm755 session/vela-labwc-session $(DESTDIR)$(PREFIX)/bin/vela-labwc-session
	install -Dm644 session/labwc/rc.xml $(SHARE)/vela/labwc/rc.xml
	install -Dm644 session/labwc/environment $(SHARE)/vela/labwc/environment
	install -Dm755 session/labwc/autostart $(SHARE)/vela/labwc/autostart
	install -Dm644 session/vela-labwc.desktop $(SHARE)/wayland-sessions/vela-labwc.desktop

.PHONY: all helper daemon test test-js test-sh install install-system
