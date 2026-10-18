// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Tema: unico oggetto da cui i plugin leggono colori, font e misure.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var t: Config.theme

    readonly property color background: t.colors.background
    readonly property color surface: t.colors.surface
    readonly property color border: t.colors.border
    readonly property color foreground: t.colors.foreground
    readonly property color muted: t.colors.muted
    readonly property color dim: t.colors.dim
    readonly property color accent: t.colors.accent
    readonly property color warning: t.colors.warning
    readonly property color error: t.colors.error

    // Stati dei pannelli (D-023): riempimenti e bordi ricavati dal colore del testo.
    readonly property color stateHover: Qt.alpha(foreground, t.states.hover)
    readonly property color stateCursor: Qt.alpha(foreground, t.states.cursor)
    readonly property color stateSelected: Qt.alpha(foreground, t.states.selected)
    readonly property color softBorder: Qt.alpha(foreground, t.states.border)

    readonly property color barBackground: Qt.alpha(background, t.barOpacity)

    readonly property string fontFamily: t.font.family
    readonly property string iconFamily: t.font.iconFamily
    readonly property string monoFamily: t.font.monoFamily
    readonly property int fontSize: t.font.size
    readonly property int iconSize: t.font.iconSize
    // Nella barra testo e icone hanno una dimensione propria; le icone mantengono la differenza rispetto al testo.
    readonly property int barFontSize: t.font.barSize
    readonly property int barIconSize: t.font.barSize + (t.font.iconSize - t.font.size)

    readonly property int barHeight: t.layout.barHeight
    readonly property int radius: t.layout.radius
    readonly property int barRadius: t.layout.barRadius
    readonly property int spacing: t.layout.spacing
    readonly property int padding: t.layout.padding
    readonly property int gap: t.layout.gap
    readonly property int menuWidth: t.layout.menuWidth
    readonly property int menuRows: t.layout.menuRows
    readonly property int rowHeight: t.layout.rowHeight
    readonly property int panelWidth: t.layout.panelWidth
    readonly property int panelMargin: t.layout.panelMargin
}
