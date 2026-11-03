// NetBird in the network tab's vpn section. Needs no sudo because the daemon's
// socket is world-writable. `netbird up` opens the browser when the session
// has expired and blocks until login finishes, so the row stays on "starting…".
import Quickshell.Io
import QtQuick
import "../../components"
import "../../state"

VpnProvider {
    id: root

    name: "NetBird"
    interfaces: ["wt0"]

    upCommand: ["netbird", "up"]
    downCommand: ["netbird", "down"]

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function parse(text) {
        let s
        try { s = JSON.parse(text) } catch (e) { available = false; return }
        available = true
        active = !!(s.management && s.management.connected)
        busy = !active && s.daemonStatus === "Connecting"
        warning = /login|expired/i.test(s.daemonStatus || "")
        status = warning ? "needs login" : busy ? "connecting" : active ? "connected" : "disconnected"
        if (!active) { detail = ""; return }
        const ip = (s.netbirdIp || "").split("/")[0]
        const peers = s.peers || {}
        detail = ip + " · " + (peers.connected || 0) + "/" + (peers.total || 0) + " peers"
    }

    Process {
        id: statusProc
        command: ["netbird", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // The lock screen reads `active` too, so keep polling with the tab closed.
    Timer {
        interval: IslandState.tab === "network" ? 5000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
