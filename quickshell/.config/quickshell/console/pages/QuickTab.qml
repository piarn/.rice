// The console's quick page: the whole machine as one readout, each line one
// click or one key. Opened from the top row's battery or empty space, or
// $mod+Shift+n.
//
//   NETWORK   wi-fi, bluetooth, airplane, vpn (› opens their page)
//   AUDIO     volume and mic levels, the output in use (› sound)
//   DISPLAY   brightness, night light (and its warmth while on), layout
//   SYSTEM    silence, keep awake, power mode, battery
//   PLAYING   the MPRIS player that's playing (or was last), when there is one
//   TOOLS     screenshot, color picker, lock, power; the tray's icons
//
// Keys (dim on each row): w b a · v m o · n d · s i p · x; j/k + Space for
// the rest (island/Tab.qml). Middle click mutes a level, the wheel steps it.
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

    onOpened: {
        layoutsShown = false
        BrightnessState.refresh()
        RiceState.refresh()   // outputs may have been plugged in since
        VolumeState.refreshExtras()   // the output's codec
    }

    hotkeys: ({
        "w": () => NetworkState.setWifiEnabled(!NetworkState.wifiEnabled),
        "b": () => BluetoothState.togglePower(),
        "a": () => NetworkState.toggleAirplane(),
        "v": () => VolumeState.toggleMute(VolumeState.sinkAudio),
        "m": () => VolumeState.toggleMute(VolumeState.sourceAudio),
        "o": () => menu.openPopup("sound"),
        "n": () => { if (NightLightState.available) NightLightState.active = !NightLightState.active },
        "d": () => menu.layoutsShown = !menu.layoutsShown,
        "s": () => NotificationState.toggleDnd(),
        "i": () => IdleState.inhibit = !IdleState.inhibit,
        "p": () => menu.cycleProfile(),
        "x": () => { if (menu.player && menu.player.canTogglePlaying) menu.player.togglePlaying() },
    })

    // Playing player first, else whichever is paused with a track loaded.
    readonly property var player: {
        const players = Mpris.players.values
        return players.find(p => p.isPlaying) || players.find(p => p.trackTitle) || null
    }

    readonly property var wifi: NetworkState.devices.find(d => d.type === "wifi" && d.connected) || null

    function profileName(p) {
        if (p === PowerProfile.PowerSaver) return "power saver"
        if (p === PowerProfile.Performance) return "performance"
        return "balanced"
    }

    function cycleProfile() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced]
        if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance)
        const i = order.indexOf(PowerProfiles.profile)
        PowerProfiles.profile = order[(i + 1) % order.length]
    }

    readonly property bool canMirror: RiceState.usableLayouts.indexOf("present") >= 0
        && RiceState.usableLayouts.indexOf("extend") >= 0
    readonly property bool mirroring: RiceState.currentLayout === "present"

    function batteryText() {
        const d = UPower.displayDevice
        const charging = d.state === UPowerDeviceState.Charging
        const parts = [Math.round(d.percentage * 100) + "%"]
        if (charging) parts.push("charging")
        else if (d.state === UPowerDeviceState.FullyCharged) parts.push("full")
        const secs = charging ? d.timeToFull : d.timeToEmpty
        if (secs > 0) {
            const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60)
            parts.push((h > 0 ? h + "h " + m + "m" : m + "m") + (charging ? " to full" : " left"))
        }
        if (Math.abs(d.changeRate) > 0.05) parts.push(Math.abs(d.changeRate).toFixed(1) + " W")
        return parts.join(" · ")
    }

    // close first, so the console isn't in the screenshot or under the picker
    function act(cmd) {
        close()
        Quickshell.execDetached(["sh", "-c", "sleep 0.2; " + cmd])
    }

    // ---- NETWORK
    SectionHeader { title: "network"; topGap: 0 }

    ReadoutRow {
        id: wifiRow
        label: "wi-fi"
        value: !NetworkState.wifiEnabled ? "off"
            : menu.wifi ? menu.wifi.connection + " · " + menu.wifi.signal + "%" : "not connected"
        valueColor: NetworkState.wifiEnabled && !menu.wifi ? Colors.amber : Colors.fg
        light: NetworkState.wifiEnabled
        opens: true
        key: "w"
        selected: menu.selectedRow === wifiRow
        onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
        onOpened: menu.openPopup("network")
    }
    ReadoutRow {
        id: btRow
        label: "bluetooth"
        dim: !BluetoothState.available
        value: !BluetoothState.available ? "no adapter" : !BluetoothState.powered ? "off"
            : BluetoothState.connectedDevices.length ? BluetoothState.connectedDevices.map(d => d.name).join(", ") : "on"
        light: BluetoothState.powered
        opens: true
        key: "b"
        selected: menu.selectedRow === btRow
        onToggled: BluetoothState.togglePower()
        onOpened: menu.openPopup("bluetooth")
    }
    ReadoutRow {
        id: airRow
        label: "airplane"
        value: NetworkState.airplane ? "every radio off" : "off"
        valueColor: NetworkState.airplane ? Colors.amber : Colors.gray2
        light: NetworkState.airplane
        key: "a"
        selected: menu.selectedRow === airRow
        onToggled: NetworkState.toggleAirplane()
    }
    ReadoutRow {
        id: vpnRow
        visible: NetworkState.vpns.length > 0 || ExtrasState.vpns.some(v => v.available)
        label: "vpn"
        value: NetworkState.activeVpns.length ? NetworkState.activeVpns.join(", ") : "none"
        valueColor: NetworkState.activeVpns.length ? Colors.fg : Colors.gray2
        opens: true
        selected: menu.selectedRow === vpnRow
        onOpened: menu.openPopup("network")
    }

    // ---- AUDIO
    SectionHeader { title: "audio" }

    LevelRow {
        id: volRow
        label: "volume"
        key: "v"
        value: VolumeState.sinkAudio ? VolumeState.sinkAudio.volume : 0
        muted: VolumeState.sinkAudio ? VolumeState.sinkAudio.muted : false
        selected: menu.selectedRow === volRow
        onMoved: (v) => VolumeState.setVolume(false, v)
        onStepped: (d) => VolumeState.adjustVolume(d)
        onToggled: VolumeState.toggleMute(VolumeState.sinkAudio)
    }
    LevelRow {
        id: micRow
        visible: VolumeState.sourceAudio !== null
        label: "mic"
        key: "m"
        value: VolumeState.sourceAudio ? VolumeState.sourceAudio.volume : 0
        muted: VolumeState.sourceAudio ? VolumeState.sourceAudio.muted : false
        selected: menu.selectedRow === micRow
        onMoved: (v) => VolumeState.setVolume(true, v)
        onStepped: (d) => VolumeState.adjustMicVolume(d)
        onToggled: VolumeState.toggleMute(VolumeState.sourceAudio)
    }
    ReadoutRow {
        id: outRow
        label: "output"
        value: {
            const codec = VolumeState.activeCodec(VolumeState.cardForSink())
            return (VolumeState.sinkName || "none") + (codec ? " · " + codec : "")
        }
        opens: true
        key: "o"
        selected: menu.selectedRow === outRow
        onOpened: menu.openPopup("sound")
    }

    // ---- DISPLAY
    SectionHeader { title: "display" }

    LevelRow {
        id: brightRow
        visible: BrightnessState.available
        label: "brightness"
        value: BrightnessState.value
        selected: menu.selectedRow === brightRow
        onMoved: (v) => BrightnessState.set(v)
        onStepped: (d) => BrightnessState.set(BrightnessState.value + d)
    }
    ReadoutRow {
        id: nightRow
        label: "night light"
        dim: !NightLightState.available
        value: !NightLightState.available ? "install wlsunset" : NightLightState.active ? NightLightState.temperature + "K" : "off"
        light: NightLightState.active
        key: "n"
        selected: menu.selectedRow === nightRow
        onToggled: if (NightLightState.available) NightLightState.active = !NightLightState.active
    }
    LevelRow {
        id: warmRow
        visible: NightLightState.active
        readonly property int span: NightLightState.maxTemperature - NightLightState.minTemperature
        label: "warmth"
        value: (NightLightState.temperature - NightLightState.minTemperature) / span
        valueText: NightLightState.temperature + "K"
        selected: menu.selectedRow === warmRow
        onMoved: (v) => NightLightState.setTemperature(NightLightState.minTemperature + v * span)
        onStepped: (d) => NightLightState.setTemperature(NightLightState.temperature + (d > 0 ? 100 : -100))
        onToggled: NightLightState.active = false
    }
    ReadoutRow {
        id: layoutRow
        label: "layout"
        value: menu.mirroring ? "mirroring to hdmi" : RiceState.currentLayout || "—"
        light: menu.canMirror ? menu.mirroring : undefined
        opens: true
        key: "d"
        selected: menu.selectedRow === layoutRow
        // with HDMI in, the light mirrors; the › always lists every layout
        onToggled: RiceState.applyLayout(menu.mirroring ? "extend" : "present")
        onOpened: menu.layoutsShown = !menu.layoutsShown
    }
    LayoutList {
        visible: menu.layoutsShown
    }

    // ---- SYSTEM
    SectionHeader { title: "system" }

    ReadoutRow {
        id: dndRow
        label: "silence"
        value: NotificationState.dnd ? "critical only" : NotificationState.notifications.length + " unread"
        light: NotificationState.dnd
        opens: true
        key: "s"
        selected: menu.selectedRow === dndRow
        onToggled: NotificationState.toggleDnd()
        onOpened: menu.openPopup("notifications")
    }
    ReadoutRow {
        id: awakeRow
        label: "keep awake"
        value: IdleState.inhibit ? "no idle lock" : "off"
        light: IdleState.inhibit
        key: "i"
        selected: menu.selectedRow === awakeRow
        onToggled: IdleState.inhibit = !IdleState.inhibit
    }
    ReadoutRow {
        id: powerRow
        label: "power mode"
        value: menu.profileName(PowerProfiles.profile)
        key: "p"
        selected: menu.selectedRow === powerRow
        onOpened: menu.cycleProfile()
    }
    ReadoutRow {
        id: batteryRow
        visible: UPower.displayDevice.isLaptopBattery
        label: "battery"
        value: menu.batteryText()
        valueColor: UPower.displayDevice.percentage <= 0.15 ? Colors.red
            : UPower.displayDevice.percentage <= 0.3 ? Colors.amber : Colors.fg
        selected: menu.selectedRow === batteryRow
    }

    // ---- PLAYING
    SectionHeader {
        visible: menu.player !== null
        title: "playing"

        TextButton {
            label: "prev"
            baseColor: Colors.gray2
            enabled: menu.player !== null && menu.player.canGoPrevious
            onClicked: menu.player.previous()
        }
        TextButton {
            label: "next"
            baseColor: Colors.gray2
            enabled: menu.player !== null && menu.player.canGoNext
            onClicked: menu.player.next()
        }
    }
    ReadoutRow {
        id: playRow
        visible: menu.player !== null
        label: menu.player && menu.player.isPlaying ? "▶ " + (menu.player.identity || "") : "‖ " + (menu.player ? menu.player.identity || "" : "")
        value: menu.player ? [menu.player.trackTitle, menu.player.trackArtist].filter(s => s).join(" — ") : ""
        light: menu.player !== null && menu.player.isPlaying
        key: "x"
        selected: menu.selectedRow === playRow
        onToggled: if (menu.player && menu.player.canTogglePlaying) menu.player.togglePlaying()
    }

    // ---- TOOLS
    SectionHeader {
        title: "tools"
        Item { width: 1; height: 1 }
    }

    Flow {
        width: parent.width
        leftPadding: Style.inset
        rightPadding: Style.inset
        spacing: 6

        TextButton {
            label: "screenshot"
            baseColor: Colors.gray2
            onClicked: menu.act("g=$(slurp) && grim -g \"$g\" - | wl-copy")
        }
        TextButton {
            label: "color picker"
            baseColor: Colors.gray2
            onClicked: menu.act("exec \"$HOME/.local/bin/color-pick\"")
        }
        TextButton {
            label: "lock"
            baseColor: Colors.gray2
            onClicked: {
                menu.close()
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/dots-lock"])
            }
        }
        TextButton {
            label: "power…"
            baseColor: Colors.red
            onClicked: IslandState.openRun(":")
        }
    }

    // the tray: apps' StatusNotifierItem icons. Left click activates
    // (menu-only items open their menu), right click opens the menu, middle
    // click is the secondary action, wheel scrolls.
    Item {
        width: parent.width
        height: Style.rowHeight
        visible: trayRepeater.count > 0

        Flow {
            anchors.left: parent.left
            anchors.leftMargin: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                id: trayRepeater
                model: SystemTray.items

                delegate: Rectangle {
                    id: trayItem
                    required property var modelData
                    width: 24
                    height: 24
                    radius: Style.round
                    color: trayMouse.containsMouse ? Style.tint(Colors.fg, 0.08) : "transparent"
                    border.width: modelData.status === Status.NeedsAttention ? Style.border : 0
                    border.color: Colors.amber

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
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

        MonoText {
            anchors.right: parent.right
            anchors.rightMargin: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.gray
            text: menu.hoveredTitle
        }
    }
}
