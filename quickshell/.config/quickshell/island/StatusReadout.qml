// The top row's right piece: a short readout, only what matters right now.
//
//   ♪ 37   ◠ azh   ▮ 79%                                   (normal)
//   ■ 3   ᛒ 50%   🎤 muted   ♪ 37   ◠ offline   ▮ 12%     (things need you)
//
//   notifications  only with unread ones or silence on
//   bluetooth      only while something's connected: its battery, or name
//   mic            only while muted or an app is recording
//   volume, network, and the battery on a laptop
//
// Left click opens that item's page in the console (again closes it); right
// or middle click is the quick action (silence, bluetooth off, mute, wi-fi
// off); the wheel steps volume and mic. Amber and red only for problems.
// The item whose page is open has the accent underline. Clicking the
// readout's empty space opens the quick page.
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import quickshell
import "../state"
import "../components"

Item {
    id: root

    required property var screen
    implicitWidth: row.implicitWidth
    implicitHeight: Style.barHeight

    readonly property string openHere: IslandState.screen === screen ? IslandState.tab : ""
    function openTab(name) { IslandState.toggle(name, root.screen) }

    readonly property real pct: UPower.displayDevice.percentage * 100
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery && !charging
        && UPower.displayDevice.state !== UPowerDeviceState.FullyCharged
    readonly property var wifi: NetworkState.devices.find(d => d.type === "wifi" && d.connected) || null
    readonly property var bt: BluetoothState.connectedDevices.length ? BluetoothState.connectedDevices[0] : null

    // one item: a small icon and its value
    component Segment: Item {
        id: seg
        property string glyph: ""
        property string label: ""
        property color tint: Colors.gray2
        property string page: ""
        signal clicked()
        signal toggled()
        signal wheeled(int steps)

        readonly property bool active: page !== "" && root.openHere === page
        width: segRow.implicitWidth + 14
        height: Style.barHeight

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            color: segMouse.containsMouse ? Style.tint(Colors.fg, 0.06) : "transparent"
        }
        Rectangle {
            visible: seg.active
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            width: segRow.implicitWidth
            height: 2
            color: Colors.neon
        }

        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 14
                color: seg.active || segMouse.containsMouse ? Colors.fg : seg.tint
                text: seg.glyph
            }
            MonoText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                color: seg.active || segMouse.containsMouse ? Colors.fg : seg.tint
                text: seg.label
            }
        }

        MouseArea {
            id: segMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => m.button === Qt.LeftButton ? seg.clicked() : seg.toggled()
            onWheel: (w) => seg.wheeled(w.angleDelta.y > 0 ? 1 : -1)
        }
    }

    // the readout's empty space: the quick page
    MouseArea {
        anchors.fill: parent
        onClicked: root.openTab("quick")
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Segment {
            visible: NotificationState.dnd || NotificationState.notifications.length > 0
            page: "notifications"
            glyph: NotificationState.dnd ? "\u{e7f6}" : "\u{e7f4}"   // notifications_off / notifications
            label: NotificationState.notifications.length ? String(NotificationState.notifications.length)
                : NotificationState.dnd ? "silenced" : ""
            tint: NotificationState.dnd ? Colors.gray : Colors.fg
            onClicked: root.openTab("notifications")
            onToggled: NotificationState.toggleDnd()
        }

        Segment {
            visible: root.bt !== null
            page: "bluetooth"
            glyph: "\u{e1a8}"   // bluetooth_connected
            label: !root.bt ? "" : root.bt.batteryAvailable ? Math.round(root.bt.battery * 100) + "%" : root.bt.name
            tint: root.bt && root.bt.batteryAvailable && root.bt.battery <= 0.15 ? Colors.amber : Colors.gray2
            onClicked: root.openTab("bluetooth")
            onToggled: BluetoothState.togglePower()
        }

        Segment {
            readonly property var audio: VolumeState.sourceAudio
            visible: (audio !== null && audio.muted) || VolumeState.recording.length > 0
            page: "sound"
            glyph: VolumeState.micIcon()
            label: audio && audio.muted ? "muted" : "live"
            tint: audio && audio.muted ? Colors.gray : Colors.amber
            onClicked: root.openTab("sound")
            onToggled: VolumeState.toggleMute(audio)
            onWheeled: (steps) => VolumeState.adjustMicVolume(steps / Style.segments)
        }

        Segment {
            readonly property var audio: VolumeState.sinkAudio
            page: "sound"
            glyph: VolumeState.speakerIcon()
            label: !audio ? "—" : audio.muted ? "muted" : String(Math.round(audio.volume * 100))
            tint: audio && audio.muted ? Colors.gray : Colors.gray2
            onClicked: root.openTab("sound")
            onToggled: VolumeState.toggleMute(audio)
            onWheeled: (steps) => VolumeState.adjustVolume(steps / Style.segments)
        }

        Segment {
            readonly property var p: NetworkState.primary
            readonly property bool offline: !p || !p.connected
            page: "network"
            glyph: NetworkState.airplane ? "\u{e195}" : NetworkState.icon(p)   // airplanemode_active
            label: NetworkState.airplane ? "airplane"
                : offline ? (NetworkState.wifiEnabled ? "offline" : "wi-fi off")
                : p.type === "wifi" ? p.connection : p.type === "wwan" ? "mobile" : "wired"
            tint: NetworkState.airplane ? Colors.amber
                : offline ? Colors.red
                : p.type === "wifi" && p.signal < 25 ? Colors.red
                : p.type === "wifi" && p.signal < 50 ? Colors.amber : Colors.gray2
            onClicked: root.openTab("network")
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
        }

        Segment {
            visible: UPower.displayDevice.isLaptopBattery
            page: "quick"
            glyph: BatteryState.icon(root.pct, root.charging)
            label: Math.round(root.pct) + "%"
            tint: root.onBattery && root.pct <= 15 ? Colors.red
                : root.onBattery && root.pct <= 30 ? Colors.amber : Colors.gray2
            onClicked: root.openTab("quick")
            onToggled: root.openTab("quick")
        }
    }
}
