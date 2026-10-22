// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Foglio di stile Qt (QSS) ricavato dal tema di Vela (D-049): le app Qt (per esempio PCManFM-Qt) prendono colori, font e forma
// dagli stessi token di theme.jsonc. Funzione pura: nessun colore è scritto qui, tutto viene da `theme`.
.pragma library

// "#rrggbb" + opacità 0..1 -> "rgba(r,g,b,a)" (il QSS non ha il canale alfa in esadecimale come QML)
function rgba(hex, a) {
    var h = String(hex).replace("#", "");
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h.slice(0, 6), 16);
    return "rgba(" + ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a + ")";
}

function rgb(hex) {
    var n = parseInt(String(hex).replace("#", "").slice(0, 6), 16);
    return ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255);
}

// kdeglobals privato per il tema piattaforma «kde» di Qt: icone e palette dai token (evita i colori di default, es. il bordo verdastro del focus).
function kdeglobals(theme) {
    var c = theme.colors, icons = (theme.qt || {}).iconTheme || "";
    var out = [];
    function set(name, bg, fg, alt) {
        out.push("[Colors:" + name + "]", "BackgroundNormal=" + rgb(bg), "BackgroundAlternate=" + rgb(alt || bg), "ForegroundNormal=" + rgb(fg),
                 "ForegroundInactive=" + rgb(c.muted), "ForegroundActive=" + rgb(c.accent), "ForegroundLink=" + rgb(c.accent), "ForegroundVisited=" + rgb(c.muted),
                 "ForegroundNegative=" + rgb(c.error), "ForegroundNeutral=" + rgb(c.warning), "ForegroundPositive=" + rgb(c.accent),
                 "DecorationFocus=" + rgb(c.accent), "DecorationHover=" + rgb(c.accent), "");
    }
    set("Window", c.background, c.foreground);
    set("View", c.background, c.foreground);
    set("Button", c.surface, c.foreground);
    set("Tooltip", c.surface, c.foreground);
    set("Complementary", c.background, c.foreground);
    set("Selection", c.accent, c.foreground);
    if (icons !== "") out.push("[Icons]", "Theme=" + icons, "");
    return out.join("\n");
}

function qss(theme) {
    var c = theme.colors, f = theme.font, l = theme.layout, s = theme.states || {};
    var hover = rgba(c.foreground, s.hover !== undefined ? s.hover : 0.08);
    var cursor = rgba(c.foreground, s.cursor !== undefined ? s.cursor : 0.12);
    var selected = rgba(c.accent, 0.3);
    var r = Number(l.radius) || 0;
    var soft = rgba(c.foreground, s.border !== undefined ? s.border : 0.12);   // bordi come nei pannelli (D-023), non il colore `border` della barra
    var pad = Math.max(2, Math.round((Number(l.spacing) || 6) / 2));
    return [
        "/* Generato da `vela theme qt` dal tema di Vela: non modificare, si rigenera. */",
        "* { font-family: \"" + f.family + "\"; font-size: " + f.size + "px; color: " + c.foreground + "; }",
        "QWidget { background-color: " + c.background + "; selection-background-color: " + selected + "; selection-color: " + c.foreground + "; }",
        "QWidget:disabled { color: " + c.dim + "; }",
        "QDialog, QMainWindow { background-color: " + c.background + "; }",
        "QLabel { background: transparent; }",
        "QToolBar, QMenuBar, QStatusBar { background-color: " + c.background + "; border: none; }",
        "QToolBar { border-bottom: 1px solid " + soft + "; spacing: " + pad + "px; }",
        "QMenuBar::item { background: transparent; padding: " + (pad + 4) + "px " + (pad + 8) + "px; }",
        "QMenuBar::item:selected { background-color: " + cursor + "; }",
        "QToolButton { background: transparent; border: none; padding: " + pad + "px; border-radius: " + r + "px; }",
        "QToolButton:hover { background-color: " + hover + "; }",
        "QToolButton:pressed, QToolButton:checked { background-color: " + cursor + "; }",
        "QPushButton { background-color: " + c.surface + "; border: 1px solid " + soft + "; border-radius: " + r + "px; padding: " + pad + "px 14px; }",
        "QPushButton:hover { background-color: " + hover + "; }",
        "QPushButton:pressed { background-color: " + cursor + "; }",
        "QPushButton:default, QPushButton:focus { border: 1px solid " + c.accent + "; }",
        "QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox, QPlainTextEdit, QTextEdit { background-color: " + c.surface + "; border: 1px solid " + soft + "; border-radius: " + r + "px; padding: " + pad + "px 6px; }",
        "QLineEdit:focus, QComboBox:focus, QSpinBox:focus { border: 1px solid " + c.accent + "; }",
        "QComboBox QAbstractItemView { background-color: " + c.surface + "; border: 1px solid " + soft + "; }",
        "QTreeView, QListView, QTableView, QAbstractItemView { background-color: " + c.background + "; alternate-background-color: " + c.background + "; border: none; outline: none; }",
        "QAbstractItemView::item:hover { background-color: " + hover + "; }",
        "QAbstractItemView::item:selected { background-color: " + selected + "; color: " + c.foreground + "; }",
        "QHeaderView::section { background-color: " + c.surface + "; border: none; border-right: 1px solid " + soft + "; padding: " + pad + "px 6px; color: " + c.muted + "; }",
        "QSplitter::handle { background-color: " + soft + "; }",
        "QTabWidget::pane { border: none; }",
        "QTabBar::tab { background: " + c.background + "; padding: " + pad + "px 12px; border: none; color: " + c.muted + "; }",
        "QTabBar::tab:selected { color: " + c.foreground + "; border-bottom: 2px solid " + c.accent + "; }",
        "QTabBar::tab:hover { background-color: " + hover + "; }",
        "QGroupBox { border: 1px solid " + soft + "; border-radius: " + r + "px; margin-top: 10px; padding-top: 8px; }",
        "QGroupBox::title { subcontrol-origin: margin; left: 8px; color: " + c.muted + "; }",
        "QProgressBar { background-color: " + c.surface + "; border: 1px solid " + soft + "; border-radius: " + r + "px; text-align: center; }",
        "QProgressBar::chunk { background-color: " + c.accent + "; }",
        "QScrollBar:vertical { background: " + c.background + "; width: 8px; margin: 0; }",
        "QScrollBar::handle:vertical { background: " + c.dim + "; min-height: 24px; }",
        "QScrollBar:horizontal { background: " + c.background + "; height: 8px; margin: 0; }",
        "QScrollBar::handle:horizontal { background: " + c.dim + "; min-width: 24px; }",
        "QScrollBar::add-line, QScrollBar::sub-line { height: 0; width: 0; }",
        "QMenu { background-color: " + c.surface + "; border: 1px solid " + soft + "; }",
        "QMenu::item { padding: " + pad + "px 18px; }",
        "QMenu::item:selected { background-color: " + cursor + "; }",
        "QMenu::separator { height: 1px; background: " + soft + "; margin: 4px 0; }",
        "QToolTip { background-color: " + c.surface + "; border: 1px solid " + soft + "; color: " + c.foreground + "; }",
        ""
    ].join("\n");
}
