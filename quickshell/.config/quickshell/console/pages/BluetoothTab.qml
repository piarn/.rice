// The console's bluetooth page. Opened from the top row's bluetooth, or
// `qs ipc call popup toggle bluetooth`. Rows are live BluetoothDevice objects
// (state/BluetoothState.qml), so connect/pair progress shows without any
// refresh. As readout rows:
//   ADAPTER  power, discoverable (others can find this laptop), pairable,
//            show nearby — each a light
//   PAIRED   the light is "connected": click connects or disconnects; ›
//            opens the device: address, battery, codec (audio devices),
//            trusted, blocked, wake, forget
//   NEARBY   unpaired devices a scan found (30s, time left shown); click
//            pairs
// Keys: b power · d discoverable · p pairable · n nearby · s scan.
import QtQuick
import quickshell
import "../../state"
import "../../components"
import "../../island"

Tab {
    id: menu
    name: "bluetooth"

    // address of the device whose details are open, and whose codecs are
    property string openDevice: ""
    property bool codecsOpen: false

    onOpened: {
        openDevice = ""
        codecsOpen = false
        VolumeState.refreshExtras()   // audio devices' codecs
    }

    hotkeys: ({
        "b": () => BluetoothState.togglePower(),
        "d": () => BluetoothState.toggleDiscoverable(),
        "p": () => BluetoothState.togglePairable(),
        "n": () => BluetoothState.showNearby = !BluetoothState.showNearby,
        "s": () => BluetoothState.scanning ? BluetoothState.stopScan() : BluetoothState.scan(),
    })

    function statusOf(dev, card) {
        return BluetoothState.stateText(dev) || [
            dev.connected ? "connected" : dev.paired ? "paired" : "not paired",
            VolumeState.activeCodec(card),
            dev.batteryAvailable ? Math.round(dev.battery * 100) + "%" : "",
            dev.blocked ? "blocked" : "",
        ].filter(s => s).join(" · ")
    }

    component DeviceRow: Column {
        id: row
        required property var modelData
        readonly property var dev: modelData
        readonly property bool open: menu.openDevice === dev.address
        // an audio device's sound card, while connected: its codecs
        readonly property var card: dev.connected ? VolumeState.cardForAddress(dev.address) : null
        width: menu.innerWidth
        spacing: 0

        ReadoutRow {
            id: devRow
            label: row.dev.name || row.dev.address
            labelColor: row.dev.connected ? Colors.fg : row.dev.paired ? Colors.gray2 : Colors.gray
            value: menu.statusOf(row.dev, row.card)
            valueColor: BluetoothState.stateText(row.dev) ? Colors.amber : Colors.gray2
            light: row.dev.paired || row.dev.connected ? row.dev.connected : undefined
            opens: true
            dim: row.dev.blocked
            selected: menu.selectedRow === devRow
            // paired: connect / disconnect; not paired: pair (or cancel)
            onToggled: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
            onOpened: {
                if (!row.dev.paired && !row.dev.connected) {
                    if (row.dev.pairing) row.dev.cancelPair()
                    else BluetoothState.pair(row.dev)
                    return
                }
                menu.codecsOpen = false
                menu.openDevice = row.open ? "" : row.dev.address
            }
        }

        // details
        Column {
            visible: row.open
            width: parent.width
            spacing: 0

            ReadoutRow {
                indent: 30
                label: "Address"
                value: row.dev.address
                valueColor: Colors.gray2
            }
            ReadoutRow {
                visible: row.dev.batteryAvailable
                indent: 30
                label: "Battery"
                value: Math.round(row.dev.battery * 100) + "%"
            }
            ReadoutRow {
                id: codecRow
                visible: row.card !== null && VolumeState.codecs(row.card, "music").length > 0
                indent: 30
                label: "Codec"
                value: VolumeState.activeCodec(row.card) || "off"
                opens: true
                selected: menu.selectedRow === codecRow
                onOpened: menu.codecsOpen = !menu.codecsOpen
            }
            CodecPicker {
                visible: menu.codecsOpen && card !== null
                x: Style.inset + 30
                width: parent.width - x - Style.inset
                topPadding: 2
                bottomPadding: 4
                card: row.card
            }
            ReadoutRow {
                id: trustRow
                indent: 30
                label: "Trusted"
                value: row.dev.trusted ? "reconnects on its own" : "no"
                valueColor: Colors.gray2
                light: row.dev.trusted
                selected: menu.selectedRow === trustRow
                onToggled: row.dev.trusted = !row.dev.trusted
            }
            ReadoutRow {
                id: blockRow
                indent: 30
                label: "Blocked"
                value: row.dev.blocked ? "yes" : "no"
                valueColor: row.dev.blocked ? Colors.red : Colors.gray2
                light: row.dev.blocked
                selected: menu.selectedRow === blockRow
                onToggled: row.dev.blocked = !row.dev.blocked
            }
            ReadoutRow {
                id: wakeRow
                indent: 30
                label: "Wakes the laptop"
                value: row.dev.wakeAllowed ? "yes" : "no"
                valueColor: Colors.gray2
                light: row.dev.wakeAllowed
                selected: menu.selectedRow === wakeRow
                onToggled: row.dev.wakeAllowed = !row.dev.wakeAllowed
            }
            // For stale pairings (bluez "br-connection-key-missing"): connect
            // keeps failing until the device is removed and re-paired.
            Item {
                width: parent.width
                height: Style.rowHeight
                TextButton {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.inset + 30
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Forget this device"
                    baseColor: Colors.red
                    enabled: !BluetoothState.busy(row.dev)
                    onClicked: {
                        menu.openDevice = ""
                        row.dev.forget()
                    }
                }
            }
        }
    }

    // ---- ADAPTER
    SectionHeader {
        title: BluetoothState.adapterName || "bluetooth"
        topGap: 0
    }

    ReadoutRow {
        id: powerRow
        label: "Power"
        dim: !BluetoothState.available
        value: !BluetoothState.available ? "no adapter" : BluetoothState.powered ? "on" : "off"
        light: BluetoothState.powered
        key: "b"
        selected: menu.selectedRow === powerRow
        onToggled: BluetoothState.togglePower()
    }
    ReadoutRow {
        id: discRow
        visible: BluetoothState.powered
        label: "Discoverable"
        value: BluetoothState.discoverable ? "others can find this laptop" : "hidden"
        valueColor: Colors.gray2
        light: BluetoothState.discoverable
        key: "d"
        selected: menu.selectedRow === discRow
        onToggled: BluetoothState.toggleDiscoverable()
    }
    ReadoutRow {
        id: pairRow
        visible: BluetoothState.powered
        label: "Pairable"
        value: BluetoothState.pairable ? "accepts new pairings" : "no"
        valueColor: Colors.gray2
        light: BluetoothState.pairable
        key: "p"
        selected: menu.selectedRow === pairRow
        onToggled: BluetoothState.togglePairable()
    }
    ReadoutRow {
        id: nearRow
        visible: BluetoothState.powered
        label: "Show nearby"
        value: BluetoothState.showNearby ? "on" : "off"
        valueColor: Colors.gray2
        light: BluetoothState.showNearby
        key: "n"
        selected: menu.selectedRow === nearRow
        onToggled: BluetoothState.showNearby = !BluetoothState.showNearby
    }

    // ---- PAIRED
    SectionHeader {
        visible: BluetoothState.powered
        title: "Paired"
        count: String(BluetoothState.paired.length)
    }

    MonoText {
        visible: BluetoothState.powered && BluetoothState.paired.length === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "nothing paired yet — scan below"
    }

    Repeater {
        model: BluetoothState.powered ? BluetoothState.paired : []
        delegate: DeviceRow {}
    }

    // ---- NEARBY
    SectionHeader {
        visible: BluetoothState.powered
        title: BluetoothState.scanning ? "nearby · scanning " + BluetoothState.scanLeft + "s" : "nearby"
        count: BluetoothState.showNearby && BluetoothState.nearby.length ? String(BluetoothState.nearby.length) : ""

        TextButton {
            label: BluetoothState.scanning ? "Stop" : "Scan"
            baseColor: BluetoothState.scanning ? Colors.amber : Colors.acid
            onClicked: BluetoothState.scanning ? BluetoothState.stopScan() : BluetoothState.scan()
        }
    }

    // scan progress: a line that runs out
    Item {
        visible: BluetoothState.powered && BluetoothState.scanning
        width: parent.width
        height: 6

        Rectangle {
            x: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            width: (parent.width - 2 * Style.inset) * BluetoothState.scanLeft / BluetoothState.scanSeconds
            height: 2
            color: Colors.neon
            Behavior on width { NumberAnimation { duration: 1000 } }  // a smooth countdown across 1s ticks
        }
    }

    MonoText {
        visible: BluetoothState.powered && (!BluetoothState.showNearby || BluetoothState.nearby.length === 0)
        leftPadding: Style.inset
        color: Colors.gray
        text: !BluetoothState.showNearby ? "hidden — show nearby is off"
            : BluetoothState.scanning ? "looking for devices…" : "nothing nearby — scan to look"
    }

    Repeater {
        model: BluetoothState.powered && BluetoothState.showNearby ? BluetoothState.nearby : []
        delegate: DeviceRow {}
    }

    MonoText {
        visible: BluetoothState.powered
        width: parent.width
        topPadding: 6
        leftPadding: Style.inset
        rightPadding: Style.inset
        wrapMode: Text.Wrap
        color: Colors.dim
        // ~/.local/bin/bluetooth-agent registers a NoInputNoOutput agent
        text: "pairing uses no code · a device that asks for a PIN needs bluetoothctl"
    }
}
