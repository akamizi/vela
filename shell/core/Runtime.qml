// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Stato di esecuzione condiviso (non è configurazione: non si salva e riparte dai valori qui sotto).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool barVisible: true

    // Menu/launcher: "" = chiuso, "menu" = menu completo, "apps" = solo applicazioni
    property string menuMode: ""
    // Pannello aperto: "" = nessuno, altrimenti "network", "bluetooth", "audio". Menu e pannelli si escludono.
    property string panel: ""
    // Ascissa (in pixel dello schermo) del pulsante che ha aperto il pannello: il pannello si ancora lì.
    // -1 = aperto dal menu o da IPC: resta nell'angolo accanto alla barra.
    property real panelAnchorX: -1
    function openPanel(name, anchorX) { menuMode = ""; panelAnchorX = (anchorX === undefined) ? -1 : anchorX; panel = name; }
    function closePanel() { panel = ""; panelAnchorX = -1; }
    function togglePanel(name, anchorX) { if (panel === name) closePanel(); else openPanel(name, anchorX); }

    function openMenu(mode) { panel = ""; menuMode = mode; }
    function closeMenu() { menuMode = ""; }
    function toggleMenu(mode) { menuMode = (menuMode === mode) ? "" : mode; }
}
