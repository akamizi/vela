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

        ShapePath {   // randa
            fillColor: Theme.accent
            strokeColor: "transparent"
            PathSvg { path: "M66 10 C 92 34 104 62 106 88 L 66 88 Z" }
        }
        ShapePath {   // fiocco
            fillColor: Qt.lighter(Theme.accent, 1.45)
            strokeColor: "transparent"
            PathSvg { path: "M58 26 C 44 46 36 66 32 88 L 58 88 Z" }
        }
        ShapePath {   // scafo
            fillColor: Qt.darker(Theme.accent, 1.3)
            strokeColor: "transparent"
            PathSvg { path: "M16 98 L 112 98 C 106 112 96 118 84 118 L 44 118 C 32 118 22 112 16 98 Z" }
        }
    }
}
