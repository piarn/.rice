// The login screen: a greetd greeter in the shell's own look (the lock
// screen's clock and password cells), replacing a TUI one like ly or
// tuigreet. greetd runs it as its `greetd` user inside a throwaway sway
// (greeter/sway.conf), so it can't read ~/.rice: greeter/install.sh copies
// this file, GreeterFace.qml and the few shared components it uses to
// /etc/greetd/quickshell/, a standalone quickshell config.
//
// Quickshell.Services.Greetd speaks greetd's IPC (GREETD_SOCK): createSession
// starts PAM for a user, authMessage asks for the password, and launch hands
// greetd the session command, after which greetd starts it on the same VT
// and this process quits (sway.conf then exits its sway).
//
// Without greetd (GREETD_SOCK unset) it runs as a preview: everything but
// the login itself, and Escape quits. `qs -p /etc/greetd/quickshell` from a
// terminal shows it that way.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import quickshell

ShellRoot {
    id: root
    settings.watchFiles: false

    readonly property bool preview: !Greetd.available

    // Shared by every screen's face, as on the lock screen: typing on one
    // output shows on all of them.
    property string user: ""
    property string password: ""
    property bool busy: false
    property bool failed: false
    property string status: ""
    property date now: new Date()

    // [{ name, exec, desktop }] from /usr/share/wayland-sessions
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions.length > 0 ? sessions[sessionIndex] : null

    // faces listen for this to shake their password cells
    signal rejected()

    function cycleSession(step) {
        if (sessions.length > 0)
            sessionIndex = (sessionIndex + step + sessions.length) % sessions.length
    }

    function login() {
        if (busy) return
        if (user === "") { status = "user?"; failed = true; return }
        if (session === null) { status = "no session in /usr/share/wayland-sessions"; failed = true; return }
        if (preview) { status = "preview: greetd isn't running"; failed = false; return }
        busy = true
        failed = false
        status = ""
        Greetd.createSession(user)
    }

    function fail(message) {
        busy = false
        failed = true
        password = ""
        status = message
        rejected()
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }

    // The session goes through a login shell, the same way the tty1 login
    // started it: ~/.bash_profile loads environment.d and PATH, which sway
    // and its binds rely on. sway itself goes through ~/.local/bin/sway-session
    // when that's there (GPU choice, a log, a safe-mode retry).
    function command(s) {
        const exec = s.exec.replace(/%[a-zA-Z]/g, "").trim()
        const script = exec === "sway"
            ? 's="$HOME/.local/bin/sway-session"; [ -x "$s" ] && exec "$s"; exec sway'
            : "exec " + exec
        return ["/bin/bash", "-lc", script]
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired && !echoResponse) {
                Greetd.respond(root.password)
            } else if (responseRequired) {
                // a visible prompt (an OTP, a second factor): not something
                // this screen asks for
                root.fail("unsupported prompt: " + message)
            } else if (message !== "") {
                root.status = message
                root.failed = error
            }
        }

        function onAuthFailure(message) { root.fail("wrong password") }
        function onError(error) { root.fail(error) }

        function onReadyToLaunch() {
            root.password = ""
            root.status = "starting " + root.session.name.toLowerCase() + "…"
            lastLogin.setText(root.user + "\n" + root.session.name + "\n")
            const desktop = root.session.desktop.split(";")[0] || root.session.exec.split(" ")[0]
            Greetd.launch(root.command(root.session), [
                "XDG_SESSION_TYPE=wayland",
                "XDG_CURRENT_DESKTOP=" + desktop,
                "XDG_SESSION_DESKTOP=" + desktop,
            ], true)
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Last user and session, so the next boot only asks for the password.
    // install.sh makes /var/lib/qs-greeter, owned by greetd.
    FileView {
        id: lastLogin
        path: "/var/lib/qs-greeter/last"
        printErrors: false
        blockLoading: true
    }
    readonly property var remembered: lastLogin.text().split("\n")

    Component.onCompleted: {
        if (root.user === "") root.user = remembered[0] ?? ""
    }

    // Name, Exec, DesktopNames of each visible session. awk rather than a
    // QML parser: these files are tiny and flat.
    Process {
        running: true
        command: ["sh", "-c", `
            for f in /usr/share/wayland-sessions/*.desktop; do
                [ -r "$f" ] || continue
                awk -F= '
                    /^\\[/ { s = ($0 == "[Desktop Entry]") }
                    s && $1 == "Name" && n == "" { n = substr($0, 6) }
                    s && $1 == "Exec" && e == "" { e = substr($0, 6) }
                    s && $1 == "DesktopNames" && d == "" { d = substr($0, 14) }
                    s && ($1 == "Hidden" || $1 == "NoDisplay") && $2 == "true" { h = 1 }
                    END { if (n != "" && e != "" && !h) printf "%s\\t%s\\t%s\\n", n, e, d }
                ' "$f"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l !== "").map(l => {
                    const [name, exec, desktop] = l.split("\t")
                    return { name, exec, desktop: desktop ?? "" }
                })
                list.sort((a, b) => a.name.localeCompare(b.name))
                const saved = list.findIndex(s => s.name === root.remembered[1])
                root.sessions = list
                root.sessionIndex = saved >= 0 ? saved : 0
            }
        }
    }

    // logind lets the active greeter session power off and reboot itself.
    Process { id: poweroff; command: ["systemctl", "poweroff"] }
    Process { id: reboot; command: ["systemctl", "reboot"] }
    function power(which) {
        if (preview) { status = "preview: would " + which; failed = false; return }
        status = which + "…"
        if (which === "poweroff") poweroff.running = true
        else reboot.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            color: Colors.black

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "qs-greeter"

            GreeterFace {
                anchors.fill: parent
                greeter: root
            }
        }
    }
}
