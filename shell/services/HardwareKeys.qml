// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Tasti in più del PC (multimediali, preferiti, ritaglio, Copilot): letti dalle capacità dei dispositivi di input e tradotti
// nelle scorciatoie predefinite (core/hwkeys.js). Solo lettura di /proc/bus/input/devices, senza privilegi.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/hwkeys.js" as HwKeys

Singleton {
    id: root

    // Per le prove si può indicare un altro file (stesso formato di /proc/bus/input/devices).
    readonly property string devicesPath: Quickshell.env("VELA_INPUT_DEVICES") || "/proc/bus/input/devices"

    property var codes: ({})
    // [{combo, command, description, code?}]: le scorciatoie dei soli tasti presenti (più il tasto Copilot, sempre).
    readonly property var bindings: HwKeys.hardwareBindings(codes, I18n.tr)

    function refresh() { if (!reader.running) reader.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: reader
        command: ["cat", root.devicesPath]
        stdout: StdioCollector { onStreamFinished: root.codes = HwKeys.keyCodes(text) }
        // File illeggibile: nessun tasto riconosciuto, resta il Copilot.
        onExited: code => { if (code !== 0) root.codes = {}; }
    }
}
