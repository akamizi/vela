// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Stato di esecuzione condiviso (non è configurazione: non si salva e riparte dai valori qui sotto).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property bool barVisible: true

    // Menu/launcher: "" = chiuso, "menu" = menu completo, "apps" = solo applicazioni
    property string menuMode: ""
    function openMenu(mode) { menuMode = mode; }
    function closeMenu() { menuMode = ""; }
    function toggleMenu(mode) { menuMode = (menuMode === mode) ? "" : mode; }
}
