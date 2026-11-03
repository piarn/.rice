// Tailscale in the network tab's vpn section. Needs no sudo because arnas is
// the tailscale operator (`tailscale set --operator=$USER`).
import Quickshell.Io
import QtQuick
import "../../components"
import "../../state"

VpnProvider {
    id: root

    name: "Tailscale"
    interfaces: ["tailscale0"]

    upCommand: ["tailscale", "up"]
    downCommand: ["tailscale", "down"]

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function parse(text) {
        let s
        try { s = JSON.parse(text) } catch (e) { available = false; return }
        available = true
        active = s.BackendState === "Running"
        busy = s.BackendState === "Starting"
        warning = s.BackendState === "NeedsLogin" || s.BackendState === "NeedsMachineAuth"
        status = warning ? "needs login" : busy ? "connecting" : active ? "connected" : "disconnected"
        if (!active) { detail = ""; return }
        const peers = Object.values(s.Peer || {})
        const ip = ((s.Self && s.Self.TailscaleIPs) || [])[0] || ""
        detail = ip + " · " + peers.filter(p => p.Online).length + "/" + peers.length + " peers"
    }

    Process {
        id: statusProc
        command: ["tailscale", "status", "--json"]
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
