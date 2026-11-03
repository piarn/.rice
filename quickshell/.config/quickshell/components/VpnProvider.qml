// Base for a VPN client that isn't a NetworkManager profile (Mullvad,
// Tailscale, NetBird, ...). An opt-in extra ships one as
// extras/<name>/Vpn.qml (see state/ExtrasState.qml); the network tab's vpn
// section lists every `available` one next to the NM profiles.
//
//   VpnProvider {
//       name: "Tailscale"
//       available: ...            // CLI installed + daemon reachable
//       active: ...               // tunnel up
//       detail: "100.64.0.1 · 3/5 peers"
//       detailComponent: Qt.resolvedUrl("TailscaleDetail.qml")  // optional
//       upCommand: ["tailscale", "up"]
//       downCommand: ["tailscale", "down"]
//       function refresh() { ... }  // popup opened / after run() finishes
//   }
//
// Only one VPN is up at a time, whichever extras are installed: starting one
// first runs every other available provider's downCommand. Two tunnels fight
// over routes and firewalls (Tailscale's firewall drops NetBird's traffic,
// whose range is inside 100.64.0.0/10; Mullvad's blocks other tunnels).
//
// detailComponent is an Item shown under the row when it's expanded; it
// gets `provider` (this object) and `width` set.
import Quickshell
import Quickshell.Io
import QtQuick
import "../state"

Scope {
    id: root

    property string name: ""
    property bool available: false
    property bool active: false
    property bool busy: false        // connecting/disconnecting
    property bool warning: false     // up but degraded, or blocking traffic
    property string status: active ? "connected" : "disconnected"
    property string detail: ""
    property url detailComponent: ""
    // Prefixes of the NM connection names this client's tunnel shows up
    // under (e.g. wg0-mullvad, "ProtonVPN CH#242") — hidden from the NM
    // profile list so it isn't listed twice.
    property var interfaces: []
    // false: no [connect]/[disconnect] (e.g. ZeroTier, which joins networks
    // instead); everything happens in detailComponent.
    property bool canToggle: true
    // Set while a text field in detailComponent is focused, so the popup
    // takes the keyboard exclusively (see island/Island.qml).
    property bool wantsKeyboard: false

    // argv that bring the tunnel up and down. A provider without them (e.g.
    // ZeroTier) overrides toggle() instead, and is never stopped by another.
    property var upCommand: []
    property var downCommand: []

    property string actionStatus: ""
    readonly property bool running: actionProc.running

    function toggle() {
        if (active || busy) {
            run("stopping", downCommand)
            return
        }
        const quote = (s) => "'" + String(s).replace(/'/g, "'\\''") + "'"
        const stops = ExtrasState.vpns
            .filter(v => v !== root && v.available && v.downCommand.length)
            .map(v => v.downCommand.map(quote).join(" ") + " >/dev/null 2>&1; ")
        run("starting", ["sh", "-c", stops.join("") + 'exec "$@"', "sh"].concat(upCommand))
    }
    function refresh() {}

    // Starting one may have stopped the others, so show that straight away.
    onRunningChanged: {
        if (running) return
        for (const v of ExtrasState.vpns) if (v !== root) v.refresh()
    }

    // Runs one CLI action at a time; failures land in actionStatus.
    function run(label, cmd) {
        if (actionProc.running) return
        actionStatus = label + "…"
        actionProc.label = label
        actionProc.command = cmd
        actionProc.running = true
    }

    Process {
        id: actionProc
        property string label: ""
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }
        onExited: (exitCode) => {
            const err = (actionStderr.text.trim() || actionStdout.text.trim()).split("\n").pop()
            root.actionStatus = exitCode === 0 ? "" : "failed: " + (err || actionProc.label)
            root.refresh()
        }
    }
}
