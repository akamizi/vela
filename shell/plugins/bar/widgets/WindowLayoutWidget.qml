// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Disposizione delle finestre del contenitore col focus (colonne, righe, schede, pila, flottante). Clic = successiva,
// clic destro = precedente (stesso effetto di `vela ipc call layout next|prev`). Serve il demone dati: senza, non compare.
BarItem {
    id: root
    readonly property string kind: Compositor.windowLayout
    visible: Compositor.windowLayoutKnown
    tooltip: kind === "splith" ? I18n.tr("Finestre affiancate")
           : kind === "splitv" ? I18n.tr("Finestre una sopra l'altra")
           : kind === "tabbed" ? I18n.tr("Schede")
           : kind === "stacking" ? I18n.tr("Pila")
           : kind === "floating" ? I18n.tr("Finestra flottante") : ""
    onClicked: button => {
        if (button === Qt.LeftButton) Compositor.cycleWindowLayout(1);
        else if (button === Qt.RightButton) Compositor.cycleWindowLayout(-1);
    }
    BarIcon {
        text: root.kind === "splith" ? Icons.layoutSplith
            : root.kind === "splitv" ? Icons.layoutSplitv
            : root.kind === "tabbed" ? Icons.layoutTabbed
            : root.kind === "stacking" ? Icons.layoutStacking : Icons.layoutFloating
    }
}
