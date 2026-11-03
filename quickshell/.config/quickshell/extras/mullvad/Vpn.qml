// Mullvad in the network tab's vpn section. Needs no sudo: the daemon takes
// commands from any local user. --wait on both, so the next VPN only starts
// once this one is really down (see components/VpnProvider.qml).
import Quickshell.Io
import QtQuick
import "../../components"
import "../../state"

VpnProvider {
    id: root

    name: "Mullvad"
    interfaces: ["wg0-mullvad"]

    upCommand: ["mullvad", "connect", "--wait"]
    downCommand: ["mullvad", "disconnect", "--wait"]

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function parse(text) {
        let s
        try { s = JSON.parse(text) } catch (e) { available = false; return }
        available = true
        const d = s.details || {}
        const loc = d.location || {}
        // "Block traffic when the VPN is disconnected" keeps traffic blocked while off
        const blocked = !!d.locked_down
        active = s.state === "connected"
        busy = s.state === "connecting" || s.state === "disconnecting"
        warning = s.state === "error" || (blocked && !active)
        status = s.state === "error" ? "error · traffic blocked"
            : busy ? s.state
            : active ? "connected"
            : blocked ? "off · traffic blocked" : "disconnected"
        detail = active ? [[loc.city, loc.country].filter(x => x).join(", "), loc.ipv4 || loc.ipv6 || ""].filter(x => x).join(" · ") : ""
    }

    Process {
        id: statusProc
        command: ["mullvad", "status", "--json"]
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
