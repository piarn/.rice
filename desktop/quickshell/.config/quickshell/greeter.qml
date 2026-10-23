// The login screen: what greetd shows on tty1 instead of a TUI login.
// The lock screen's own face (popups/lock/LockFace.qml: clock, date,
// password cells), so logging in and unlocking look the same, plus a line
// naming who logs in and into which session (Tab switches it).
//
// Not part of the desktop shell (that's shell.qml): ~/.rice/install.sh
// copies this whole directory to /var/lib/dots-greeter/shell (the greetd
// user can't read $HOME) and /usr/local/bin/dots-greeter runs it in a
// bare sway as the greetd user:
//   quickshell -p /var/lib/dots-greeter/shell/greeter.qml
// DOTS_GREETER_USER names the account to log in (set by install.sh in
// /etc/greetd/dots-greeter.sway). Authentication is greetd's (PAM), through
// Quickshell.Services.Greetd; this file only relays the password and
// starts the chosen session.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import quickshell
import "components"
import "popups/lock"

ShellRoot {
    id: root

    readonly property string user: Quickshell.env("DOTS_GREETER_USER") || ""
    property string host: "localhost"

    // What each session runs once greetd has logged the user in.
    readonly property var sessions: [
        {
            name: "sway",
            command: ["/usr/local/bin/sway-session"],
            env: ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=sway", "XDG_SESSION_DESKTOP=sway"],
        },
        {
            name: "terminal",
            // the user's own login shell, on the console
            command: ["/bin/sh", "-c", "exec \"$(getent passwd \"$(id -un)\" | cut -d: -f7)\" -l"],
            env: ["XDG_SESSION_TYPE=tty"],
        },
    ]
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex]

    // Shared by every screen, like the lock screen: typing on one shows on all.
    property string currentText: ""
    property bool busy: false
    property bool showFailure: false
    property string statusMessage: root.user === "" ? "DOTS_GREETER_USER isn't set" : ""
    property date now: new Date()

    // The password typed before greetd asked for it; sent on its prompt.
    property string pending: ""

    function submit() {
        if (busy || currentText === "" || user === "") return
        busy = true
        showFailure = false
        statusMessage = ""
        if (Greetd.state === GreetdState.Authenticating) {
            // a later prompt (second factor, ...): answer it directly
            Greetd.respond(currentText)
        } else {
            pending = currentText
            Greetd.createSession(user)
        }
    }

    function fail(message) {
        busy = false
        pending = ""
        currentText = ""
        statusMessage = message
        showFailure = true
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }

    function cycleSession() {
        sessionIndex = (sessionIndex + 1) % sessions.length
        lastSession.setText(session.name + "\n")
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (root.pending !== "") {
                    Greetd.respond(root.pending)
                    root.pending = ""
                } else {
                    // another prompt: show it and wait for the next Enter
                    root.busy = false
                    root.currentText = ""
                    root.statusMessage = message.toLowerCase().replace(/:\s*$/, "")
                }
            } else {
                // info/error text (fprintd, account notices): shown, acknowledged
                if (message !== "") root.statusMessage = message.toLowerCase()
                Greetd.respond("")
            }
        }

        function onAuthFailure(message) { root.fail("wrong password") }
        function onError(error) { root.fail(String(error).toLowerCase()) }

        function onReadyToLaunch() {
            root.statusMessage = "starting " + root.session.name + "…"
            Greetd.launch(root.session.command, root.session.env)
        }
    }

    // Which session was picked last time, kept in the greetd user's home.
    FileView {
        id: lastSession
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/dots-greeter-session"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const i = root.sessions.findIndex(s => s.name === text().trim())
            if (i >= 0) root.sessionIndex = i
        }
    }

    // Tells dots-greeter's watchdog this loaded; without it within 15s the
    // greeter gives way to a text login.
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dots-greeter.ready"
        printErrors: false
        Component.onCompleted: setText("ready\n")
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: { const h = text().trim(); if (h !== "") root.host = h }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dots-greeter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: Colors.black

            LockFace {
                id: face
                anchors.fill: parent

                now: root.now
                busy: root.busy
                failed: root.showFailure
                status: root.statusMessage
                statusLine.visible: false

                onTextChanged: root.currentText = text
                onAccepted: root.submit()

                input.Keys.onTabPressed: root.cycleSession()

                Component.onCompleted: Qt.callLater(() => focusInput())

                Connections {
                    target: root
                    function onShowFailureChanged() { if (root.showFailure) face.reject() }
                    function onCurrentTextChanged() {
                        if (face.text !== root.currentText) face.text = root.currentText
                    }
                }
            }

            // who and what, in the lock status line's style
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.12
                spacing: Style.gap

                MonoText { text: "●"; color: Colors.acid }
                MonoText { text: root.user + "@" + root.host; font.bold: true }
                MonoText { text: "│"; color: Colors.dim }
                MonoText { text: root.session.name; color: Colors.neon }
                MonoText { text: "· tab"; color: Colors.gray2 }
            }
        }
    }
}
