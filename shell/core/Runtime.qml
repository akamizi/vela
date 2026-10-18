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
    function openPanel(name) { menuMode = ""; panel = name; }
    function closePanel() { panel = ""; }
    function togglePanel(name) { if (panel === name) panel = ""; else openPanel(name); }

    function openMenu(mode) { panel = ""; menuMode = mode; }
    function closeMenu() { menuMode = ""; }
    function toggleMenu(mode) { menuMode = (menuMode === mode) ? "" : mode; }
}
