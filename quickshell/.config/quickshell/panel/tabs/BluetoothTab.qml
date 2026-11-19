// The control panel's bluetooth tab. Opened from the strip's bluetooth icon
// (or `qs ipc call popup toggle bluetooth`). Rows are live BluetoothDevice
// objects (state/BluetoothState.qml), so connect/pair progress shows
// without any refresh.
//  - header: the adapter, power, and switches for discoverable (others can
//    find this laptop), pairable, and showing nearby devices
//  - paired: click a device for its details (address, battery, trusted,
//    blocked) and every action: connect, trust, block, forget
//  - nearby: unpaired devices a [scan] found; the scan runs 30s, with the
//    time left shown, [stop] ends it
import QtQuick
import quickshell
import "../../state"
import "../../components"
import "../../island"

Tab {
    id: menu
    name: "bluetooth"

    // address of the device whose details are open
    property string openDevice: ""

    onOpened: {
        openDevice = ""
        VolumeState.refreshExtras()   // audio devices' codecs
    }

    // A small on/off switch: "label on" in accent, "label off" grey.
    component Switch: Rectangle {
        id: sw
        property string label: ""
        property bool on: false
        signal toggled()
        width: swText.implicitWidth + track.width + 26
        height: 28
        radius: Style.round
        color: Style.tint(Colors.fg, swMouse.containsMouse ? 0.08 : 0.04)

        MonoText {
            id: swText
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 11
            color: sw.on ? Colors.fg : Colors.gray2
            text: sw.label
        }
        // the switch itself
        Rectangle {
            id: track
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 14
            radius: Style.round
            color: sw.on ? Colors.neon : Colors.dim

            Rectangle {
                width: 10
                height: 10
                radius: Style.round
                anchors.verticalCenter: parent.verticalCenter
                x: sw.on ? parent.width - width - 2 : 2
                color: sw.on ? Colors.black : Colors.gray2
                Behavior on x { NumberAnimation { duration: Style.fast } }
            }
        }
        MouseArea {
            id: swMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component DeviceRow: Column {
        id: row
        required property var modelData
        readonly property var dev: modelData
        readonly property string status: BluetoothState.stateText(dev)
        readonly property bool open: menu.openDevice === dev.address
        // an audio device's sound card, while connected: its codecs
        readonly property var card: dev.connected ? VolumeState.cardForAddress(dev.address) : null
        width: menu.innerWidth
        spacing: 4

        Rectangle {
            width: parent.width
            height: 40
            radius: Style.round
            color: rowMouse.containsMouse ? Style.tint(Colors.fg, 0.07) : row.open || row.dev.connected ? Style.tint(Colors.fg, 0.04) : "transparent"

            Marker { visible: row.dev.connected }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.openDevice = row.open ? "" : row.dev.address
            }

            Icon {
                id: devIcon
                anchors.left: parent.left
                anchors.leftMargin: Style.inset
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 17
                color: row.dev.connected ? Colors.neon : row.dev.paired ? Colors.fg : Colors.gray
                text: BluetoothState.icon(row.dev)
            }

            Column {
                anchors.left: devIcon.right
                anchors.right: actions.left
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter

                MonoText {
                    width: parent.width
                    font.pixelSize: Style.fontSize
                    elide: Text.ElideRight
                    color: row.dev.connected ? Colors.fg : row.dev.paired ? Colors.fg : Colors.gray2
                    text: row.dev.name || row.dev.address
                }
                MonoText {
                    width: parent.width
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    color: row.status ? Colors.amber : Colors.gray2
                    text: row.status || [
                        row.dev.connected ? "connected" : row.dev.paired ? "paired" : "not paired",
                        VolumeState.activeCodec(row.card),
                        row.dev.batteryAvailable ? "battery " + Math.round(row.dev.battery * 100) + "%" : "",
                        row.dev.blocked ? "blocked" : "",
                    ].filter(s => s).join(" · ")
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: Style.inset
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !row.dev.blocked
                    label: row.dev.connected ? "disconnect" : row.dev.paired ? "connect"
                        : row.dev.pairing ? "cancel" : "pair"
                    baseColor: row.dev.connected ? Colors.gray2 : Colors.acid
                    enabled: !BluetoothState.busy(row.dev) || row.dev.pairing
                    onClicked: {
                        if (row.dev.connected) row.dev.disconnect()
                        else if (row.dev.paired) row.dev.connect()
                        else if (row.dev.pairing) row.dev.cancelPair()
                        else BluetoothState.pair(row.dev)
                    }
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.gray2
                    text: row.open ? "\u{e5ce}" : "\u{e5cf}"   // expand_less / expand_more
                }
            }
        }

        // details
        Column {
            visible: row.open
            width: parent.width
            leftPadding: 37
            spacing: 4

            MonoText {
                font.pixelSize: 11
                color: Colors.gray2
                text: [row.dev.address, row.dev.icon || "", row.dev.batteryAvailable ? "battery " + Math.round(row.dev.battery * 100) + "%" : ""]
                    .filter(s => s).join(" · ")
            }
            MonoText {
                font.pixelSize: 11
                color: Colors.gray2
                text: [row.dev.paired ? "paired" : "not paired", row.dev.bonded ? "bonded" : "",
                       row.dev.trusted ? "trusted (reconnects on its own)" : "not trusted"].filter(s => s).join(" · ")
            }
            // audio devices: pick the codec
            CodecPicker {
                width: parent.width - parent.leftPadding
                card: row.card
            }
            Flow {
                width: parent.width - parent.leftPadding
                spacing: 12

                TextButton {
                    label: row.dev.trusted ? "untrust" : "trust"
                    baseColor: Colors.gray2
                    onClicked: row.dev.trusted = !row.dev.trusted
                }
                TextButton {
                    label: row.dev.blocked ? "unblock" : "block"
                    baseColor: row.dev.blocked ? Colors.red : Colors.gray2
                    onClicked: row.dev.blocked = !row.dev.blocked
                }
                TextButton {
                    label: row.dev.wakeAllowed ? "wake off" : "wake on"
                    baseColor: Colors.gray2
                    onClicked: row.dev.wakeAllowed = !row.dev.wakeAllowed
                }
                // For stale pairings (bluez "br-connection-key-missing"):
                // connect keeps failing until the device is removed and
                // re-paired from scratch.
                TextButton {
                    visible: row.dev.paired || row.dev.connected
                    label: "forget"
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

    // header
    SectionHeader {
        title: !BluetoothState.available ? "bluetooth · no adapter"
            : (BluetoothState.adapterName || "bluetooth") + (BluetoothState.powered ? "" : " · off")

        TextButton {
            visible: BluetoothState.available
            label: BluetoothState.powered ? "turn off" : "turn on"
            baseColor: BluetoothState.powered ? Colors.acid : Colors.red
            onClicked: BluetoothState.togglePower()
        }
    }

    Flow {
        visible: BluetoothState.powered
        width: parent.width
        leftPadding: Style.inset
        rightPadding: Style.inset
        spacing: 6

        Switch {
            label: "discoverable"
            on: BluetoothState.discoverable
            onToggled: BluetoothState.toggleDiscoverable()
        }
        Switch {
            label: "pairable"
            on: BluetoothState.pairable
            onToggled: BluetoothState.togglePairable()
        }
        Switch {
            label: "show nearby"
            on: BluetoothState.showNearby
            onToggled: BluetoothState.showNearby = !BluetoothState.showNearby
        }
    }

    MonoText {
        visible: BluetoothState.available && !BluetoothState.powered
        leftPadding: Style.inset
        color: Colors.gray
        text: "turn bluetooth on to see your devices"
    }

    // paired
    Divider { visible: BluetoothState.powered }

    SectionHeader {
        visible: BluetoothState.powered
        title: "paired"
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

    // nearby
    Divider { visible: BluetoothState.powered }

    SectionHeader {
        visible: BluetoothState.powered
        title: BluetoothState.scanning ? "nearby · scanning " + BluetoothState.scanLeft + "s" : "nearby"
        count: BluetoothState.showNearby && BluetoothState.nearby.length ? String(BluetoothState.nearby.length) : ""

        TextButton {
            label: BluetoothState.scanning ? "stop" : "scan"
            baseColor: BluetoothState.scanning ? Colors.amber : Colors.acid
            onClicked: BluetoothState.scanning ? BluetoothState.stopScan() : BluetoothState.scan()
        }
    }

    // scan progress
    Rectangle {
        visible: BluetoothState.powered && BluetoothState.scanning
        width: parent.width
        height: 2
        color: Colors.dim

        Rectangle {
            width: parent.width * BluetoothState.scanLeft / BluetoothState.scanSeconds
            height: parent.height
            color: Colors.neon
            Behavior on width { NumberAnimation { duration: 900 } }
        }
    }

    MonoText {
        visible: BluetoothState.powered && (!BluetoothState.showNearby || BluetoothState.nearby.length === 0)
        leftPadding: Style.inset
        color: Colors.gray
        text: !BluetoothState.showNearby ? "hidden — switch on [show nearby]"
            : BluetoothState.scanning ? "looking for devices…" : "nothing nearby — [scan] to look"
    }

    Repeater {
        model: BluetoothState.powered && BluetoothState.showNearby ? BluetoothState.nearby : []
        delegate: DeviceRow {}
    }

    MonoText {
        visible: BluetoothState.powered
        width: parent.width
        leftPadding: Style.inset
        rightPadding: Style.inset
        wrapMode: Text.Wrap
        font.pixelSize: 11
        color: Colors.gray
        // ~/.local/bin/bluetooth-agent registers a NoInputNoOutput agent
        text: "pairing uses no code · a device that asks for a PIN needs bluetoothctl"
    }
}
