// The control panel's quick tab: everything at a glance, one click each.
// Opened from the strip's tune icon, the battery, empty strip space or
// $mod+Shift+n. Parts:
//  - tiles: click toggles; the › on a tile opens that feature's own tab
//    (wi-fi → network, bluetooth, silence → notifications, mic → sound).
//    The display tile mirrors the laptop onto HDMI (the `present` layout)
//    or back (`extend`) when HDMI is plugged in, and its › lists every
//    screen layout. Screenshot, color picker and lock act at once and close
//    the panel.
//  - sliders: volume (› for the sound tab), mic, brightness, and the night
//    light's warmth while it's on. Middle click mutes, wheel steps.
//  - media controls for the MPRIS player that's playing (or was last)
//  - tray: the StatusNotifierItem icons apps register (Slack, nm-applet, …).
//    Left click activates (menu-only items open their menu), right click
//    opens the menu, middle click is the secondary action, wheel scrolls.
//  - battery (with time left and power draw) and power
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import quickshell
import "../../state"
import "../../components"
import "../../island"

Tab {
    id: menu
    name: "quick"

    property string hoveredTitle: ""
    property bool layoutsShown: false
    // two tiles a row, Style.gap apart
    readonly property int tileWidth: (innerWidth - Style.gap) / 2

    onOpened: {
        layoutsShown = false
        BrightnessState.refresh()
        RiceState.refresh()   // outputs may have been plugged in since
    }

    readonly property var primaryNet: NetworkState.primary

    // Playing player first, else whichever is paused with a track loaded.
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) || players.find(p => p.trackTitle) || null
    }

    function profileName(p) {
        if (p === PowerProfile.PowerSaver) return "power saver"
        if (p === PowerProfile.Performance) return "performance"
        return "balanced"
    }

    readonly property bool canMirror: RiceState.usableLayouts.indexOf("present") >= 0
        && RiceState.usableLayouts.indexOf("extend") >= 0
    readonly property bool mirroring: RiceState.currentLayout === "present"

    function cycleProfile() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced]
        if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance)
        const i = order.indexOf(PowerProfiles.profile)
        PowerProfiles.profile = order[(i + 1) % order.length]
    }

    // close first, so the panel isn't in the screenshot or under the picker
    function act(cmd) {
        close()
        Quickshell.execDetached(["sh", "-c", "sleep 0.2; " + cmd])
    }

    // tiles
    Grid {
        columns: 2
        spacing: Style.gap

        ToggleTile {
            width: menu.tileWidth
            icon: NetworkState.wifiEnabled ? NetworkState.icon(menu.primaryNet && menu.primaryNet.type === "wifi" ? menu.primaryNet : null) : "\u{e648}"   // wifi_off
            title: "Wi-Fi"
            subtitle: {
                if (!NetworkState.wifiEnabled) return "off"
                const w = NetworkState.devices.find(d => d.type === "wifi" && d.connected)
                const link = w ? w.connection + " · " + w.signal + "%" : "not connected"
                return [link].concat(NetworkState.activeVpns.map(v => "vpn " + v)).join(" · ")
            }
            active: NetworkState.wifiEnabled
            hasDetail: true
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
            onDetail: menu.openPopup("network")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: BluetoothState.powered ? (BluetoothState.connectedDevices.length ? "\u{e1a8}" : "\u{e1a7}") : "\u{e1a9}"
            title: "Bluetooth"
            subtitle: !BluetoothState.available ? "no adapter"
                : !BluetoothState.powered ? "off"
                : BluetoothState.connectedDevices.length ? BluetoothState.connectedDevices.map(d => d.name).join(", ")
                : "on · nothing connected"
            active: BluetoothState.powered
            hasDetail: true
            onToggled: BluetoothState.togglePower()
            onDetail: menu.openPopup("bluetooth")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{e195}"   // airplanemode_active
            title: "Airplane mode"
            subtitle: NetworkState.airplane ? "every radio off" : "off"
            active: NetworkState.airplane
            onToggled: NetworkState.toggleAirplane()
        }

        ToggleTile {
            width: menu.tileWidth
            icon: NotificationState.dnd ? "\u{e7f6}" : "\u{e7f5}"   // notifications_off / notifications
            title: "Silence"
            subtitle: NotificationState.dnd ? "toasts hidden · critical only"
                : NotificationState.notifications.length + " unread"
            active: NotificationState.dnd
            hasDetail: true
            onToggled: NotificationState.toggleDnd()
            onDetail: menu.openPopup("notifications")
        }

        ToggleTile {
            width: menu.tileWidth
            readonly property var audio: VolumeState.sourceAudio
            icon: VolumeState.micIcon()
            title: "Mute mic"
            subtitle: !audio ? "no microphone" : audio.muted ? "muted" : "on · " + Math.round(audio.volume * 100) + "%"
            active: audio !== null && audio.muted
            hasDetail: true
            onToggled: VolumeState.toggleMute(audio)
            onDetail: menu.openPopup("sound")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{efef}"   // coffee (keep awake)
            title: "Keep awake"
            subtitle: IdleState.inhibit ? "no idle lock" : "off"
            active: IdleState.inhibit
            onToggled: IdleState.inhibit = !IdleState.inhibit
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{f03d}"   // nightlight
            title: "Night light"
            subtitle: !NightLightState.available ? "install wlsunset"
                : NightLightState.active ? NightLightState.temperature + "K" : "off"
            active: NightLightState.active
            onToggled: if (NightLightState.available) NightLightState.active = !NightLightState.active
        }

        ToggleTile {
            width: menu.tileWidth
            icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "\u{efde}"   // battery_saver
                : PowerProfiles.profile === PowerProfile.Performance ? "\u{e9e4}" : "\u{eaf6}"   // speed / balance
            title: "Power mode"
            subtitle: menu.profileName(PowerProfiles.profile)
            active: PowerProfiles.profile !== PowerProfile.Balanced
            onToggled: menu.cycleProfile()
        }

        ToggleTile {
            width: menu.tileWidth
            icon: menu.mirroring ? "\u{e0e2}" : "\u{e30c}"   // screen_share / desktop_windows
            title: "Display"
            subtitle: menu.mirroring ? "mirroring to hdmi"
                : menu.canMirror ? RiceState.currentLayout + " · click to mirror"
                : RiceState.currentLayout || "layouts"
            active: menu.mirroring || menu.layoutsShown
            hasDetail: true
            onToggled: {
                if (menu.canMirror) RiceState.applyLayout(menu.mirroring ? "extend" : "present")
                else menu.layoutsShown = !menu.layoutsShown
            }
            onDetail: menu.layoutsShown = !menu.layoutsShown
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{ec08}"   // screenshot_region
            title: "Screenshot"
            subtitle: "region → clipboard"
            onToggled: menu.act("g=$(slurp) && grim -g \"$g\" - | wl-copy")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{e3b8}"   // colorize
            title: "Color picker"
            subtitle: "#hex → clipboard"
            onToggled: menu.act("exec \"$HOME/.local/bin/color-pick\"")
        }

        ToggleTile {
            width: menu.tileWidth
            icon: "\u{e897}"   // lock
            title: "Lock"
            subtitle: "lock the screen now"
            onToggled: {
                menu.close()
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/dots-lock"])
            }
        }
    }

    LayoutList {
        visible: menu.layoutsShown
    }

    Divider {}

    // sliders
    LevelRow {
        icon: VolumeState.speakerIcon()
        value: VolumeState.sinkAudio ? VolumeState.sinkAudio.volume : 0
        muted: VolumeState.sinkAudio ? VolumeState.sinkAudio.muted : false
        onMoved: (v) => VolumeState.setVolume(false, v)
        onStepped: (d) => VolumeState.adjustVolume(d)
        onToggled: VolumeState.toggleMute(VolumeState.sinkAudio)
        expandable: true
        expandGlyph: "\u{e5cc}"   // chevron_right: the sound tab
        onExpandClicked: menu.openPopup("sound")
    }

    LevelRow {
        visible: VolumeState.sourceAudio !== null
        icon: VolumeState.micIcon()
        value: VolumeState.sourceAudio ? VolumeState.sourceAudio.volume : 0
        muted: VolumeState.sourceAudio ? VolumeState.sourceAudio.muted : false
        onMoved: (v) => VolumeState.setVolume(true, v)
        onStepped: (d) => VolumeState.adjustMicVolume(d)
        onToggled: VolumeState.toggleMute(VolumeState.sourceAudio)
        expandable: true
        expandGlyph: "\u{e5cc}"   // chevron_right: the sound tab
        onExpandClicked: menu.openPopup("sound")
    }

    LevelRow {
        visible: BrightnessState.available
        icon: "\u{e1ac}"   // brightness_high
        value: BrightnessState.value
        onMoved: (v) => BrightnessState.set(v)
        onStepped: (d) => BrightnessState.set(BrightnessState.value + d)
    }

    // night light warmth: left is warmer
    LevelRow {
        visible: NightLightState.active
        readonly property int span: NightLightState.maxTemperature - NightLightState.minTemperature
        icon: "\u{f03d}"   // nightlight
        value: (NightLightState.temperature - NightLightState.minTemperature) / span
        valueText: NightLightState.temperature + "K"
        onMoved: (v) => NightLightState.setTemperature(NightLightState.minTemperature + v * span)
        onStepped: (d) => NightLightState.setTemperature(NightLightState.temperature + (d > 0 ? 100 : -100))
        onToggled: NightLightState.active = false
    }

    // media
    Item {
        visible: menu.player !== null
        width: parent.width
        height: visible ? 34 : 0

        Column {
            anchors.left: parent.left
            anchors.right: mediaButtons.left
            anchors.leftMargin: 4
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            MonoText {
                width: parent.width
                elide: Text.ElideRight
                color: Colors.fg
                text: menu.player ? menu.player.trackTitle || menu.player.identity : ""
            }
            MonoText {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                font.pixelSize: 11
                color: Colors.gray2
                text: menu.player ? [menu.player.trackArtist, menu.player.identity]
                    .filter(s => s && s !== menu.player.trackTitle).join(" · ") : ""
            }
        }

        Row {
            id: mediaButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [
                    { glyph: "\u{e045}", enabled: menu.player && menu.player.canGoPrevious, act: () => menu.player.previous() },   // skip_previous
                    { glyph: menu.player && menu.player.isPlaying ? "\u{e034}" : "\u{e037}",   // pause / play_arrow
                      enabled: menu.player && menu.player.canTogglePlaying, act: () => menu.player.togglePlaying() },
                    { glyph: "\u{e044}", enabled: menu.player && menu.player.canGoNext, act: () => menu.player.next() },   // skip_next
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: 32
                    height: 32
                    radius: Style.round
                    color: mediaMouse.containsMouse && modelData.enabled ? Style.tint(Colors.fg, 0.06) : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        font.pixelSize: 18
                        color: parent.modelData.enabled ? Colors.acid : Colors.gray
                        text: parent.modelData.glyph
                    }
                    MouseArea {
                        id: mediaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.act()
                    }
                }
            }
        }
    }

    Divider {}

    // tray
    SectionHeader {
        title: "tray"

        MonoText {
            width: Math.min(implicitWidth, menu.innerWidth - 60)
            elide: Text.ElideRight
            color: Colors.gray2
            text: menu.hoveredTitle
        }
    }

    MonoText {
        visible: trayRepeater.count === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "no tray apps running"
    }

    Flow {
        width: parent.width
        spacing: 6
        visible: trayRepeater.count > 0

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: Rectangle {
                id: trayItem
                required property var modelData
                width: 36
                height: 36
                radius: Style.round
                color: Style.tint(Colors.fg, trayMouse.containsMouse ? 0.08 : 0.04)
                border.width: modelData.status === Status.NeedsAttention ? Style.border : 0
                border.color: Colors.amber

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 20
                    source: trayItem.modelData.icon
                    opacity: trayItem.modelData.status === Status.Passive ? 0.5 : 1
                }

                function openMenu() {
                    const p = trayItem.mapToItem(null, 0, trayItem.height + 4)
                    trayItem.modelData.display(menu, p.x, p.y)
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onContainsMouseChanged: menu.hoveredTitle = containsMouse
                        ? (trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id) : ""
                    onClicked: (mouse) => {
                        const item = trayItem.modelData
                        if (mouse.button === Qt.RightButton) {
                            if (item.hasMenu) trayItem.openMenu()
                        } else if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate()
                        } else if (item.onlyMenu && item.hasMenu) {
                            trayItem.openMenu()
                        } else {
                            item.activate()
                            menu.close()
                        }
                    }
                    onWheel: (wheel) => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }

    Divider {}

    // footer
    Item {
        width: parent.width
        height: powerBtn.implicitHeight

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: UPower.displayDevice.isLaptopBattery

            readonly property var dev: UPower.displayDevice
            readonly property bool charging: dev.state === UPowerDeviceState.Charging

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.gray2
                text: BatteryState.icon(parent.dev.percentage * 100, parent.charging)
            }
            MonoText {
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.gray2
                text: {
                    const d = parent.dev
                    const parts = [Math.round(d.percentage * 100) + "%"]
                    if (parent.charging) parts.push("charging")
                    else if (d.state === UPowerDeviceState.FullyCharged) parts.push("full")
                    const secs = parent.charging ? d.timeToFull : d.timeToEmpty
                    if (secs > 0) {
                        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60)
                        parts.push((h > 0 ? h + "h " + m + "m" : m + "m") + (parent.charging ? " to full" : " left"))
                    }
                    if (Math.abs(d.changeRate) > 0.05) parts.push(Math.abs(d.changeRate).toFixed(1) + " W")
                    return parts.join(" · ")
                }
            }
        }

        TextButton {
            id: powerBtn
            anchors.right: parent.right
            anchors.rightMargin: Style.inset
            label: "power"
            baseColor: Colors.red
            onClicked: IslandState.openRun(":")
        }
    }
}
