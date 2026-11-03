// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import QtQuick
import Quickshell
import "../../../core"
import "../../../core/icons.js" as Icons
import "../../../services"
import "../../../ui"
// Microfono in uso (D-064): compare solo mentre un'app registra dal microfono, con le app nel tooltip. Lo stesso simbolo sta nel
// gruppo Indicators (acceso di default); questo elemento singolo serve a chi preferisce metterlo altrove.
BarItem {
    visible: MicUse.active
    clickable: false
    tooltip: I18n.tr("Microfono in uso") + ": " + MicUse.apps.join(", ")
    BarIcon { text: Icons.mic; color: Theme.warning }
}
