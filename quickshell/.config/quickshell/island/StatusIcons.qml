// The top-right card's contents: status icons — notifications, bluetooth,
// mic, volume, network, battery, then the control panel's own icon. Left
// click opens that icon's tab in the side panel (again closes it); right or
// middle click is the quick action (silence, bluetooth power, mute, wi-fi
// on/off); the wheel steps volume and mic. The icon of the open tab is
// marked. They turn amber/red when something needs attention (offline, weak
// wi-fi, low battery), the battery also shows its % then. Plus "tray" when
// a tray app asks for attention. Clicking the card's empty space opens the
// control panel.
import Quickshell
import Quickshell.Services.SystemTray
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

    readonly property real pct: UPower.displayDevice.percentage * 100
    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery
        && UPower.displayDevice.state !== UPowerDeviceState.Charging
        && UPower.displayDevice.state !== UPowerDeviceState.FullyCharged
    readonly property bool offline: NetworkState.kind === "none"
    readonly property bool weakWifi: NetworkState.kind === "wifi" && NetworkState.signal < 50
    readonly property bool lowBattery: onBattery && pct <= 30
    readonly property bool trayAttention: SystemTray.items.values.some(i => i.status === Status.NeedsAttention)

    // the tab open on this screen, for marking its icon
    readonly property string openHere: IslandState.screen === screen ? IslandState.tab : ""
    function openTab(name) { IslandState.toggle(name, root.screen) }

    component Seg: MonoText {
        font.pixelSize: Style.fontSize
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.openTab("quick")
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Seg {
            visible: root.trayAttention
            rightPadding: 4
            color: Colors.amber
            text: "tray"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openTab("quick")
            }
        }

        QuickIcon {
            glyph: NotificationState.dnd ? "\u{e7f6}" : NotificationState.notifications.length ? "\u{e7f7}" : "\u{e7f5}"   // notifications_off / _active / notifications
            tint: NotificationState.dnd ? Colors.amber : NotificationState.notifications.length ? Colors.acid : Colors.gray2
            active: root.openHere === "notifications"
            tip: (NotificationState.notifications.length ? NotificationState.notifications.length + " unread" : "no notifications")
                + (NotificationState.dnd ? " · silenced" : "") + " · right click: " + (NotificationState.dnd ? "unsilence" : "silence")
            onClicked: root.openTab("notifications")
            onToggled: NotificationState.toggleDnd()
        }

        QuickIcon {
            visible: BluetoothState.available
            glyph: BluetoothState.powered ? (BluetoothState.connectedDevices.length ? "\u{e1a8}" : "\u{e1a7}") : "\u{e1a9}"
            tint: BluetoothState.powered ? Colors.gray2 : Colors.dim
            active: root.openHere === "bluetooth"
            tip: (!BluetoothState.powered ? "bluetooth off"
                : BluetoothState.connectedDevices.length ? BluetoothState.connectedDevices.map(d => d.name).join(", ")
                : "bluetooth on") + " · right click: turn " + (BluetoothState.powered ? "off" : "on")
            onClicked: root.openTab("bluetooth")
            onToggled: BluetoothState.togglePower()
        }

        QuickIcon {
            readonly property var audio: VolumeState.sourceAudio
            glyph: VolumeState.micIcon()
            tint: audio && audio.muted ? Colors.dim : Colors.gray2
            active: root.openHere === "sound"
            tip: (!audio ? "no microphone" : audio.muted ? "mic muted" : "mic " + Math.round(audio.volume * 100) + "%")
                + " · right click: " + (audio && audio.muted ? "unmute" : "mute")
            onClicked: root.openTab("sound")
            onToggled: VolumeState.toggleMute(audio)
            onWheeled: (steps) => VolumeState.adjustMicVolume(steps / Style.segments)
        }

        QuickIcon {
            readonly property var audio: VolumeState.sinkAudio
            glyph: VolumeState.speakerIcon()
            tint: audio && audio.muted ? Colors.dim : Colors.gray2
            active: root.openHere === "sound"
            tip: (!audio ? "no output" : (audio.muted ? "muted" : "volume " + Math.round(audio.volume * 100) + "%")
                + " · " + VolumeState.sinkName) + " · right click: " + (audio && audio.muted ? "unmute" : "mute")
            onClicked: root.openTab("sound")
            onToggled: VolumeState.toggleMute(audio)
            onWheeled: (steps) => VolumeState.adjustVolume(steps / Style.segments)
        }

        QuickIcon {
            readonly property var p: NetworkState.primary
            glyph: NetworkState.airplane ? "\u{e195}" : NetworkState.icon(p)   // airplanemode_active
            tint: NetworkState.airplane ? Colors.amber
                : root.offline || (root.weakWifi && NetworkState.signal < 25) ? Colors.red
                : root.weakWifi ? Colors.amber : Colors.gray2
            active: root.openHere === "network"
            tip: {
                let link
                if (NetworkState.airplane) link = "airplane mode"
                else if (!p || !p.connected) link = NetworkState.wifiEnabled ? "offline" : "offline · wi-fi off"
                else link = p.type === "wifi" ? p.connection + " · " + p.signal + "%" : p.type === "wwan" ? "mobile" : "wired"
                return [link].concat(NetworkState.activeVpns.map(v => "vpn " + v)).join(" · ")
                    + " · right click: wi-fi " + (NetworkState.wifiEnabled ? "off" : "on")
            }
            onClicked: root.openTab("network")
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
        }

        Row {
            visible: UPower.displayDevice.isLaptopBattery
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            QuickIcon {
                readonly property var d: UPower.displayDevice
                readonly property bool charging: d.state === UPowerDeviceState.Charging
                glyph: BatteryState.icon(root.pct, charging)
                tint: root.lowBattery ? (root.pct <= 15 ? Colors.red : Colors.amber) : Colors.gray2
                tip: {
                    const parts = [Math.round(root.pct) + "%"]
                    if (charging) parts.push("charging")
                    else if (d.state === UPowerDeviceState.FullyCharged) parts.push("full")
                    const secs = charging ? d.timeToFull : d.timeToEmpty
                    if (secs > 0) {
                        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60)
                        parts.push((h > 0 ? h + "h " + m + "m" : m + "m") + (charging ? " to full" : " left"))
                    }
                    return parts.join(" · ")
                }
                onClicked: root.openTab("quick")
                onToggled: root.openTab("quick")
            }
            Seg {
                visible: root.lowBattery
                color: root.pct <= 15 ? Colors.red : Colors.amber
                text: Math.round(root.pct) + "%"
            }
        }

        // the control panel itself
        QuickIcon {
            glyph: "\u{e429}"   // tune
            tint: Colors.gray2
            active: root.openHere === "quick"
            tip: "control panel"
            onClicked: root.openTab("quick")
            onToggled: root.openTab("quick")
        }
    }
}
