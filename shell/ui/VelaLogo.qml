// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Logo di Vela disegnato con i colori del tema (stessa geometria di assets/logo.svg).
import QtQuick
import QtQuick.Shapes
import "../core"

Item {
    id: root

    property int size: 96
    width: size
    height: size

    Shape {
        width: 128; height: 128
        scale: root.size / 128
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {   // vela
            fillColor: Theme.accent
            strokeColor: "transparent"
            PathSvg { path: "M60.9 8.0 L 104.8 120.0 L 23.2 107.9 Z" }
        }
        ShapePath {   // faccia in ombra
            fillColor: Qt.darker(Theme.accent, 1.43)
            strokeColor: "transparent"
            PathSvg { path: "M60.9 8.0 L 48.7 95.3 L 23.2 107.9 Z" }
        }
    }
}
