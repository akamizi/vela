// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Schermata di accesso (D-055): utente, password e sessione sopra lo sfondo, con greetd.
// Indipendente da Vela: colori, font e sfondo sono qui; nessun file di Vela è richiesto.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Item {
    id: root

    // --- tema (stessi valori predefiniti di Vela; il greeter non legge file di Vela) ---
    property color cBackground: "#1a1a1a"
    property color cSurface: "#1e1e1e"
    property color cForeground: "#e4e5e6"
    property color cMuted: "#7e8087"
    property color cAccent: "#3689e6"
    property color cError: "#c6262e"
    readonly property color cBorder: Qt.alpha(cForeground, 0.22)
    property string fontFamily: "Inter"
    readonly property int fontSize: 14

    // --- configurazione (variabili d'ambiente, utili alle prove) ---
    readonly property string sessionsDir: Quickshell.env("VELA_GREETER_SESSIONS") || "/usr/share/wayland-sessions"
    // Tema di Vela, solo se installato (lettura facoltativa: nessuna dipendenza dal pacchetto vela)
    readonly property string themeFile: Quickshell.env("VELA_GREETER_THEME") || "/usr/share/vela/config/defaults/theme.jsonc"
    // Ultimo utente e ultima sessione (la cartella la crea e la rende scrivibile a `_greeter` il pacchetto)
    readonly property string stateFile: Quickshell.env("VELA_GREETER_STATE") || "/var/cache/vela-greeter/state.json"
    // Comandi di spegnimento e riavvio (separati da spazi)
    readonly property var poweroffCmd: (Quickshell.env("VELA_GREETER_POWEROFF") || "loginctl poweroff").split(" ")
    readonly property var rebootCmd: (Quickshell.env("VELA_GREETER_REBOOT") || "loginctl reboot").split(" ")
    readonly property string wallpaper: Quickshell.env("VELA_GREETER_WALLPAPER") || "/usr/share/vela-greeter/background.jpg"

    // --- stato ---
    property string user: ""            // nome di login scelto dall'elenco
    property var users: []              // [{ name, label }]: utenti con uid >= 1000
    property string lastUser: ""
    readonly property int uidMin: Number(Quickshell.env("VELA_GREETER_UID_MIN") || 1000)
    property alias password: passInput.text
    property var sessions: []           // [{ name, exec }]
    property int sessionIndex: 0
    property string info: ""
    property bool infoIsError: false
    property bool promptReady: false    // greetd attende la risposta (password)
    property string pending: ""         // password digitata prima che arrivasse la richiesta
    property bool busy: false
    property bool sessionOpen: false   // c'è una sessione greetd aperta per l'utente (create_session inviata)
    property bool retry: false         // riaprire la sessione quando greetd torna Inactive
    property bool launching: false
    property string lastSession: ""     // nome della sessione dell'ultimo accesso
    property real contentOpacity: 1     // dissolvenza dei contenuti all'accesso
    property string armedPower: ""      // "poweroff" | "reboot": premuto una volta, serve una seconda conferma
    readonly property var session: sessions.length > 0 ? sessions[sessionIndex] : null

    // Avvio di una sessione di accesso per l'utente indicato (poi arriva la richiesta della password).
    function selectUser(name) {
        for (var i = 0; i < users.length; i++)
            if (users[i].name === name) { user = name; return true; }
        return false;
    }

    // Cambio utente: chiude la sessione greetd in corso; il timer (300 ms, dopo la cancellazione) ne apre una per il nuovo utente.
    function cycleUser(step) {
        if (users.length < 2 || launching) return;
        var cur = 0;
        for (var i = 0; i < users.length; i++) if (users[i].name === user) cur = i;
        user = users[(cur + users.length + step) % users.length].name;
        passInput.text = "";
        pending = "";
        promptReady = false;
        busy = false;
        if (sessionOpen) { sessionOpen = false; Greetd.cancelSession(); }
        retryTimer.restart();
    }

    function submitUser() {
        if (user.trim() === "" || launching) return;
        promptReady = false;
        sessionOpen = true;
        Greetd.createSession(user.trim());
        passInput.forceActiveFocus();
    }

    function submitPassword() {
        if (launching || busy) return;
        if (!sessionOpen) submitUser();
        if (promptReady) respond(passInput.text);
        else pending = passInput.text;
    }

    function respond(text) {
        promptReady = false;
        pending = "";
        busy = true;
        Greetd.respond(text);
    }

    function applyTheme(text) {
        try {
            var t = JSON.parse(String(text).replace(/(^|\s)\/\/.*$/gm, "").replace(/,(\s*[}\]])/g, "$1"));
            var c = t.colors || {};
            if (c.background) cBackground = c.background;
            if (c.surface) cSurface = c.surface;
            if (c.foreground) cForeground = c.foreground;
            if (c.muted) cMuted = c.muted;
            if (c.accent) cAccent = c.accent;
            if (c.error) cError = c.error;
            if (t.font && t.font.family) fontFamily = t.font.family;
        } catch (e) { }
    }

    function applyState(text) {
        try {
            var s = JSON.parse(String(text));
            if (typeof s.session === "string") { lastSession = s.session; selectLastSession(); }
            if (typeof s.user === "string") lastUser = s.user;
            pickInitialUser();
        } catch (e) { }
    }

    // Utente iniziale: l'ultimo che ha acceduto, altrimenti il primo dell'elenco; si apre subito la sessione greetd
    // (la password si può digitare subito). Parte solo quando sono noti sia l'elenco sia il ricordo (o la sua assenza).
    property bool stateKnown: false
    function pickInitialUser() {
        if (users.length === 0 || !stateKnown || user !== "") return;
        if (!selectUser(lastUser)) user = users[0].name;
        submitUser();
    }

    function selectLastSession() {
        for (var i = 0; i < sessions.length; i++)
            if (sessions[i].name === lastSession) { sessionIndex = i; return; }
        // Nessun ricordo (primo accesso): meglio una sessione di Vela che la prima in ordine alfabetico
        for (var k = 0; k < sessions.length; k++)
            if (sessions[k].name.indexOf("Vela") === 0) { sessionIndex = k; return; }
    }

    function saveState() {
        if (session !== null) stateView.setText(JSON.stringify({ user: user.trim(), session: session.name }));
    }

    function requestPower(kind) {
        if (armedPower !== kind) { armedPower = kind; armTimer.restart(); return; }
        armedPower = "";
        Quickshell.execDetached(kind === "poweroff" ? poweroffCmd : rebootCmd);
    }

    function cycleSession(step) {
        if (sessions.length === 0) return;
        sessionIndex = (sessionIndex + sessions.length + step) % sessions.length;
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                promptReady = true;
                busy = false;
                if (pending !== "") respond(pending);
            } else {
                root.info = message;
                root.infoIsError = error;
            }
        }

        function onAuthFailure(message) {
            busy = false;
            promptReady = false;
            sessionOpen = false;
            pending = "";
            passInput.text = "";
            root.info = "Accesso non riuscito";
            root.infoIsError = true;
            // greetd chiude la sessione dopo l'errore: se ne riapre una per il tentativo successivo, ma solo quando
            // lo stato è tornato Inactive (una createSession subito dopo la cancellazione confonde le risposte)
            root.retry = true;
        }

        function onStateChanged() {
            if (root.retry && Greetd.state === GreetdState.Inactive && !root.launching) retryTimer.restart();
        }

        function onReadyToLaunch() {
            if (root.session === null) {
                root.info = "Nessuna sessione disponibile";
                root.infoIsError = true;
                Greetd.cancelSession();
                return;
            }
            root.saveState();
            root.launching = true;
            fadeOut.start();
        }

        function onError(error) {
            busy = false;
            sessionOpen = false;
            root.info = error;
            root.infoIsError = true;
        }
    }

    FileView { path: root.themeFile; printErrors: false; onLoaded: root.applyTheme(text()) }
    FileView {
        id: stateView; path: root.stateFile; printErrors: false
        onLoaded: { root.stateKnown = true; root.applyState(text()) }
        onLoadFailed: { root.stateKnown = true; root.pickInitialUser() }
    }
    Timer { id: armTimer; interval: 4000; onTriggered: root.armedPower = "" }
    Shortcut { sequence: "F11"; onActivated: root.requestPower("reboot") }
    Shortcut { sequence: "F12"; onActivated: root.requestPower("poweroff") }

    // Pausa prima di riaprire la sessione: la risposta di greetd alla cancellazione (che Quickshell invia da sé dopo un errore)
    // deve arrivare prima della nuova richiesta, altrimenti le risposte si sfasano di una.
    Timer {
        id: retryTimer
        interval: 300
        onTriggered: { root.retry = false; if (!root.launching && !root.sessionOpen) root.submitUser(); }
    }

    // Elenco degli utenti di login: uid >= UID_MIN (e < 60000), con una shell vera
    Process {
        id: listUsers
        command: ["sh", "-c", "getent passwd | awk -F: -v min=\"$1\" '$3 >= min && $3 < 60000 && $7 !~ /(nologin|false)$/ {split($5, g, \",\"); print $1 \"\\t\" g[1]}'", "sh", String(root.uidMin)]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.split("\n").forEach(function (l) {
                    var p = l.split("\t");
                    if (p[0] !== "") out.push({ name: p[0], label: (p[1] || "") !== "" ? p[1] : p[0] });
                });
                root.users = out;
                root.pickInitialUser();
            }
        }
    }

    // Elenco delle sessioni Wayland (nome e comando); Hidden/NoDisplay esclusi.
    Process {
        id: listSessions
        command: ["sh", "-c", 'for f in "$1"/*.desktop; do [ -r "$f" ] || continue; awk -F= \'/^Name=/ && n == "" {n = substr($0, 6)} /^Exec=/ && e == "" {e = substr($0, 6)} /^(Hidden|NoDisplay)=true/ {h = 1} END {if (!h && n != "" && e != "") print n "\\t" e}\' "$f"; done', "sh", root.sessionsDir]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.split("\n").forEach(function (l) {
                    var p = l.split("\t");
                    if (p.length === 2 && p[0] !== "") out.push({ name: p[0], exec: p[1] });
                });
                root.sessions = out;
                root.selectLastSession();
            }
        }
    }

    // Dissolvenza all'accesso: prima i contenuti, poi lo schermo intero verso il nero; solo allora parte la sessione.
    // Tra l'uscita del greeter e il compositor dell'utente c'è comunque un breve stacco nero: così sembra voluto.
    readonly property int fadeMs: Math.max(0, Number(Quickshell.env("VELA_GREETER_FADE_MS") || 250))
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: root.fadeMs }
        NumberAnimation { target: blackout; property: "opacity"; to: 1; duration: root.fadeMs * 1.4 }
        ScriptAction { script: Greetd.launch(["sh", "-c", root.session.exec], [], true) }
    }

    // --- aspetto ---
    Rectangle { anchors.fill: parent; color: root.cBackground }
    Image {
        anchors.fill: parent
        source: "file://" + root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
    }
    Rectangle { anchors.fill: parent; color: Qt.alpha(root.cBackground, 0.45) }

    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 8
        opacity: root.contentOpacity
        Repeater {
            model: [{ kind: "reboot", label: "Riavvia", key: "F11" }, { kind: "poweroff", label: "Spegni", key: "F12" }]
            delegate: Rectangle {
                required property var modelData
                width: powerLabel.implicitWidth + 24; height: 30
                color: root.cSurface
                border.width: 1; border.color: root.armedPower === modelData.kind ? root.cAccent : root.cBorder
                Text {
                    id: powerLabel
                    anchors.centerIn: parent
                    text: root.armedPower === modelData.kind ? "Conferma?" : modelData.label + " (" + modelData.key + ")"
                    color: root.armedPower === modelData.kind ? root.cForeground : root.cMuted
                    font.family: root.fontFamily; font.pixelSize: root.fontSize - 2
                }
                MouseArea { anchors.fill: parent; onClicked: root.requestPower(modelData.kind) }
            }
        }
    }

    Rectangle { id: blackout; anchors.fill: parent; color: "black"; opacity: 0; z: 100 }

    Column {
        id: card
        anchors.centerIn: parent
        width: 340
        spacing: 12
        opacity: root.contentOpacity

        SystemClock { id: clock; precision: SystemClock.Minutes }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "hh:mm")
            color: root.cForeground; font.family: root.fontFamily; font.pixelSize: 56; font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("it_IT").toString(clock.date, "dddd d MMMM")
            color: root.cMuted; font.family: root.fontFamily; font.pixelSize: root.fontSize
            bottomPadding: 12
        }

        // Utente: elenco degli account (uid >= 1000); ←/→ nel campo password o un clic cambiano utente
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            property var cur: { for (var i = 0; i < root.users.length; i++) if (root.users[i].name === root.user) return root.users[i]; return null; }
            text: !cur ? "nessun utente" : (root.users.length > 1 ? "‹  " + cur.label + "  ›" : cur.label)
            color: root.cForeground; font.family: root.fontFamily; font.pixelSize: root.fontSize + 3
            bottomPadding: 4
            MouseArea { anchors.fill: parent; onClicked: root.cycleUser(1) }
        }
        Rectangle {
            width: parent.width; height: 38; color: root.cSurface
            border.width: 1; border.color: passInput.activeFocus ? root.cAccent : root.cBorder
            TextInput {
                id: passInput
                anchors.fill: parent; anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: root.cForeground; font.family: root.fontFamily; font.pixelSize: root.fontSize
                selectionColor: root.cAccent; clip: true; focus: true
                enabled: !root.launching
                onAccepted: root.submitPassword()
                Keys.onLeftPressed: root.cycleUser(-1)
                Keys.onRightPressed: root.cycleUser(1)
                Keys.onUpPressed: root.cycleSession(-1)
                Keys.onDownPressed: root.cycleSession(1)
                Text { visible: !passInput.text && !passInput.activeFocus; text: "Password"; color: root.cMuted; font: passInput.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Sessione (ambiente desktop): tutte le voci in vista, quella scelta evidenziata; clic oppure ↑/↓ nel campo password
        Text {
            text: "Sessione"
            color: root.cMuted; font.family: root.fontFamily; font.pixelSize: root.fontSize - 2
            topPadding: 6
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.sessions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool chosen: index === root.sessionIndex
                    width: chipText.implicitWidth + 20; height: 30
                    color: chosen ? root.cAccent : root.cSurface
                    border.width: 1; border.color: chosen ? root.cAccent : root.cBorder
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.modelData.name
                        color: parent.chosen ? root.cBackground : root.cForeground
                        font.family: root.fontFamily; font.pixelSize: root.fontSize - 1; font.weight: parent.chosen ? Font.DemiBold : Font.Normal
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.sessionIndex = parent.index }
                }
            }
        }
        Text {
            visible: root.sessions.length === 0
            text: "nessuna sessione"; color: root.cError
            font.family: root.fontFamily; font.pixelSize: root.fontSize - 1
        }
        // Messaggio (errore o avviso) su una fascia leggibile sopra lo sfondo
        Rectangle {
            width: parent.width; height: 34
            visible: messageText.text !== ""
            color: root.cSurface
            border.width: 1; border.color: (root.infoIsError || !Greetd.available) ? root.cError : root.cBorder
            Text {
                id: messageText
                anchors.fill: parent; anchors.margins: 6
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                text: !Greetd.available ? "greetd non disponibile" : (root.busy ? "…" : root.info)
                color: root.cForeground; font.family: root.fontFamily; font.pixelSize: root.fontSize - 1
            }
        }
    }
}
