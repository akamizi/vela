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

    readonly property color barBackground: Qt.alpha(background, t.barOpacity)

    readonly property string fontFamily: t.font.family
    readonly property string iconFamily: t.font.iconFamily
    readonly property int fontSize: t.font.size
    readonly property int iconSize: t.font.iconSize

    readonly property int barHeight: t.layout.barHeight
    readonly property int radius: t.layout.radius
    readonly property int spacing: t.layout.spacing
    readonly property int padding: t.layout.padding
}
