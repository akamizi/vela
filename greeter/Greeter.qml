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
    readonly property color cBackground: "#1a1a1a"
    readonly property color cSurface: "#1e1e1e"
    readonly property color cForeground: "#e4e5e6"
    readonly property color cMuted: "#7e8087"
    readonly property color cAccent: "#3689e6"
    readonly property color cError: "#c6262e"
    readonly property color cBorder: Qt.alpha(cForeground, 0.22)
    readonly property string fontFamily: "Inter"
    readonly property int fontSize: 14

    // --- configurazione (variabili d'ambiente, utili alle prove) ---
    readonly property string sessionsDir: Quickshell.env("VELA_GREETER_SESSIONS") || "/usr/share/wayland-sessions"
    readonly property string wallpaper: Quickshell.env("VELA_GREETER_WALLPAPER") || "/usr/share/backgrounds/vela/Vela-5.jpg"

    // --- stato ---
    property alias user: userInput.text
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
    readonly property var session: sessions.length > 0 ? sessions[sessionIndex] : null

    // Avvio di una sessione di accesso per l'utente indicato (poi arriva la richiesta della password).
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

    // Pausa prima di riaprire la sessione: la risposta di greetd alla cancellazione (che Quickshell invia da sé dopo un errore)
    // deve arrivare prima della nuova richiesta, altrimenti le risposte si sfasano di una.
    Timer {
        id: retryTimer
        interval: 300
        onTriggered: { root.retry = false; if (!root.launching) root.submitUser(); }
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
            }
        }
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

    Column {
        id: card
        anchors.centerIn: parent
        width: 340
        spacing: 12
        opacity: root.launching ? 0 : 1
        NumberAnimation { id: fadeOut; target: card; property: "opacity"; to: 0; duration: 350
            onFinished: Greetd.launch(["sh", "-c", root.session.exec], [], true) }

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

        Rectangle {
            width: parent.width; height: 38; color: root.cSurface
            border.width: 1; border.color: userInput.activeFocus ? root.cAccent : root.cBorder
            TextInput {
                id: userInput
                anchors.fill: parent; anchors.margins: 10
                verticalAlignment: TextInput.AlignVCenter
                color: root.cForeground; font.family: root.fontFamily; font.pixelSize: root.fontSize
                selectionColor: root.cAccent; clip: true; focus: true
                enabled: !root.launching
                onAccepted: root.submitUser()
                KeyNavigation.tab: passInput
                Text { visible: !userInput.text && !userInput.activeFocus; text: "Utente"; color: root.cMuted; font: userInput.font; anchors.verticalCenter: parent.verticalCenter }
            }
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
                selectionColor: root.cAccent; clip: true
                enabled: !root.launching
                onAccepted: root.submitPassword()
                KeyNavigation.tab: userInput
                KeyNavigation.backtab: userInput
                Keys.onUpPressed: root.cycleSession(-1)
                Keys.onDownPressed: root.cycleSession(1)
                Text { visible: !passInput.text && !passInput.activeFocus; text: "Password"; color: root.cMuted; font: passInput.font; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Sessione: ↑/↓ nel campo password
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.session ? "‹  " + root.session.name + "  ›" : "nessuna sessione"
            color: root.cMuted; font.family: root.fontFamily; font.pixelSize: root.fontSize - 1
            topPadding: 6
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
