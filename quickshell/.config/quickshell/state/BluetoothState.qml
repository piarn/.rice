// Bluetooth, backed by the native Quickshell.Bluetooth module (bluez over
// D-Bus) — fully reactive, no polling. This used to shell out to
// bluetoothctl every 5s (plus one `bluetoothctl info` per known device)
// because Bluetooth.adapters never populated under Quickshell 0.2.1. On
// 0.3.1 it does, but only once something *binds* to it: the module starts
// tracking bluez lazily, so an imperative read right at startup still sees
// null. Everything here is a binding for that reason.
pragma Singleton
import Quickshell.Bluetooth
import QtQuick

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    readonly property bool discoverable: adapter ? adapter.discoverable : false
    readonly property bool pairable: adapter ? adapter.pairable : false
    readonly property string adapterName: adapter ? adapter.name : ""

    // the bluetooth tab's "nearby" toggle: unpaired devices a scan found
    property bool showNearby: true

    // Connected, then paired: the devices you own.
    readonly property var paired: {
        if (!adapter) return []
        return adapter.devices.values
            .filter(d => d.paired || d.connected)
            .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    }
    // Discovered and not paired, with a real name. Unnamed discoveries (bluez
    // aliases them to their address) are noise.
    readonly property var nearby: {
        if (!adapter) return []
        return adapter.devices.values
            .filter(d => !d.paired && !d.connected && d.deviceName)
            .sort((a, b) => a.name.localeCompare(b.name))
    }
    readonly property var devices: paired.concat(nearby)
    readonly property var connectedDevices: paired.filter(d => d.connected)

    function togglePower() {
        if (adapter) adapter.enabled = !adapter.enabled
    }
    function setPowered(on) {
        if (adapter) adapter.enabled = on
    }
    function toggleDiscoverable() {
        if (adapter) adapter.discoverable = !adapter.discoverable
    }
    function togglePairable() {
        if (adapter) adapter.pairable = !adapter.pairable
    }

    // A scan runs for scanSeconds, showing what's left; stopScan ends it early.
    readonly property int scanSeconds: 30
    property int scanLeft: 0

    function scan() {
        if (!adapter || !adapter.enabled) return
        adapter.discovering = true
        scanLeft = scanSeconds
        scanTick.restart()
    }

    function stopScan() {
        scanTick.stop()
        scanLeft = 0
        if (adapter) adapter.discovering = false
    }

    // Trusted so it can reconnect on its own later; pairing itself goes
    // through the agent sway starts (~/.local/bin/bluetooth-agent).
    function pair(device) {
        device.trusted = true
        device.pair()
    }

    function busy(device) {
        return device.pairing || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting
    }

    function stateText(device) {
        if (device.pairing) return "pairing…"
        if (device.state === BluetoothDeviceState.Connecting) return "connecting…"
        if (device.state === BluetoothDeviceState.Disconnecting) return "disconnecting…"
        return ""
    }

    function icon(device) {
        const i = device.icon || ""
        if (i.startsWith("audio")) return "\u{e60f}"   // bluetooth_audio
        if (i === "input-mouse") return "\u{e323}"     // mouse
        if (i === "input-keyboard") return "\u{e312}"  // keyboard
        if (i === "input-gaming") return "\u{ea28}"    // sports_esports
        if (i === "phone") return "\u{e7ba}"           // smartphone
        if (i.startsWith("computer")) return "\u{e30a}"   // computer
        return "\u{e1a7}"   // bluetooth
    }

    Timer {
        id: scanTick
        interval: 1000
        repeat: true
        onTriggered: {
            root.scanLeft = Math.max(0, root.scanLeft - 1)
            if (root.scanLeft === 0) root.stopScan()
        }
    }
}
