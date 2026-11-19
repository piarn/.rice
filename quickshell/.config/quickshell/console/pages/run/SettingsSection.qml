// Data for the run page's settings: every quick setting as a row the
// search finds — type `wifi`, `vol`, `codec`, `out`, `night`… — or `,` to
// list only settings. Rows use the command center's kinds (run/ResultRow):
// toggles stay open and flip, levels take ←/→, choices pick one of a set,
// and the "… page" rows switch the console to that page. Also the home
// screen's live status line and its row of quick toggles (`status`, `chips`).
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import "../../../state"

Item {
    id: root

    readonly property string name: "settings"
    // asks the console to show another page
    signal openPage(string page)

    function profileName(p) {
        if (p === PowerProfile.PowerSaver) return "power saver"
        if (p === PowerProfile.Performance) return "performance"
        return "balanced"
    }

    readonly property var wifi: NetworkState.devices.find(d => d.type === "wifi" && d.connected) || null
    readonly property var outCard: active ? VolumeState.cardForSink() : null

    // the home screen's one live line: what the machine is doing now
    readonly property var statusRow: ({
        kind: "status",
        text: () => [
            NetworkState.airplane ? "airplane" : root.wifi ? root.wifi.connection + " " + root.wifi.signal + "%" : NetworkState.wifiEnabled ? "offline" : "wi-fi off",
            BluetoothState.connectedDevices.length ? "bt " + BluetoothState.connectedDevices.map(d => d.name).join(", ") : "",
            VolumeState.sinkAudio ? (VolumeState.sinkAudio.muted ? "vol muted" : "vol " + Math.round(VolumeState.sinkAudio.volume * 100)) : "",
            UPower.displayDevice.isLaptopBattery ? "bat " + Math.round(UPower.displayDevice.percentage * 100) + "%" : "",
            NotificationState.notifications.length ? NotificationState.notifications.length + " unread" : "",
        ].filter(s => s).join("  ·  ")
    })

    // ... and its row of quick toggles: ←/→ pick, Enter flips
    readonly property var chipsRow: ({
        kind: "chips",
        chips: [
            { title: "Wi-Fi", on: () => NetworkState.wifiEnabled, run: () => NetworkState.setWifiEnabled(!NetworkState.wifiEnabled) },
            { title: "Bluetooth", on: () => BluetoothState.powered, run: () => BluetoothState.togglePower() },
            { title: "Microphone", on: () => VolumeState.sourceAudio !== null && !VolumeState.sourceAudio.muted, run: () => VolumeState.toggleMute(VolumeState.sourceAudio) },
            { title: "Silence", on: () => NotificationState.dnd, run: () => NotificationState.toggleDnd() },
            { title: "Night", on: () => NightLightState.active, run: () => { if (NightLightState.available) NightLightState.active = !NightLightState.active } },
            { title: "Awake", on: () => IdleState.inhibit, run: () => IdleState.inhibit = !IdleState.inhibit },
        ]
    })

    // only built while run is shown: closed, it tracks nothing
    property bool active: false

    // every setting, for the search (and `,`)
    readonly property var rows: {
        if (!active) return []
        const out = [
            { kind: "toggle", group: "settings", key: "set:wifi", title: "Wi-Fi", glyph: "\u{e63e}",
              aliases: "wifi wireless network radio internet",
              on: () => NetworkState.wifiEnabled,
              subtitle: () => !NetworkState.wifiEnabled ? "off" : root.wifi ? root.wifi.connection + " · " + root.wifi.signal + "%" : "not connected",
              run: () => NetworkState.setWifiEnabled(!NetworkState.wifiEnabled) },
            { kind: "toggle", group: "settings", key: "set:bt", title: "Bluetooth", glyph: "\u{e1a7}",
              aliases: "bt headphones headset pair",
              on: () => BluetoothState.powered,
              subtitle: () => !BluetoothState.powered ? "off" : BluetoothState.connectedDevices.map(d => d.name).join(", ") || "on",
              run: () => BluetoothState.togglePower() },
            { kind: "toggle", group: "settings", key: "set:airplane", title: "Airplane mode", glyph: "\u{e195}",
              aliases: "flight radios offline",
              on: () => NetworkState.airplane, subtitle: "every radio off",
              run: () => NetworkState.toggleAirplane() },
            { kind: "level", group: "settings", key: "set:volume", title: "Volume", glyph: "\u{e050}",
              aliases: "vol sound audio speaker loud",
              value: () => VolumeState.sinkAudio ? VolumeState.sinkAudio.volume : 0,
              muted: () => VolumeState.sinkAudio ? VolumeState.sinkAudio.muted : false,
              set: (v) => VolumeState.setVolume(false, v), adjust: (d) => VolumeState.adjustVolume(d),
              run: () => VolumeState.toggleMute(VolumeState.sinkAudio) },
            { kind: "level", group: "settings", key: "set:mic", title: "Microphone", glyph: "\u{e31d}",
              aliases: "mic input mute record",
              value: () => VolumeState.sourceAudio ? VolumeState.sourceAudio.volume : 0,
              muted: () => VolumeState.sourceAudio ? VolumeState.sourceAudio.muted : false,
              set: (v) => VolumeState.setVolume(true, v), adjust: (d) => VolumeState.adjustMicVolume(d),
              run: () => VolumeState.toggleMute(VolumeState.sourceAudio) },
            { kind: "toggle", group: "settings", key: "set:dnd", title: "Silence notifications", glyph: "\u{e7f6}",
              aliases: "dnd do not disturb quiet notifications",
              on: () => NotificationState.dnd, subtitle: () => NotificationState.dnd ? "critical only" : "off",
              run: () => NotificationState.toggleDnd() },
            { kind: "toggle", group: "settings", key: "set:awake", title: "Keep awake", glyph: "\u{efef}",
              aliases: "caffeine idle inhibit lock",
              on: () => IdleState.inhibit, subtitle: () => IdleState.inhibit ? "no idle lock" : "off",
              run: () => IdleState.inhibit = !IdleState.inhibit },
            { kind: "toggle", group: "settings", key: "set:night", title: "Night light", glyph: "\u{f03d}",
              aliases: "warm blue light redshift wlsunset",
              on: () => NightLightState.active, subtitle: () => NightLightState.active ? NightLightState.temperature + "K" : "off",
              run: () => { if (NightLightState.available) NightLightState.active = !NightLightState.active } },
            { kind: "level", group: "settings", key: "set:warmth", title: "Night light warmth", glyph: "\u{f03d}",
              aliases: "temperature kelvin warm",
              value: () => (NightLightState.temperature - NightLightState.minTemperature) / (NightLightState.maxTemperature - NightLightState.minTemperature),
              set: (v) => NightLightState.setTemperature(NightLightState.minTemperature + v * (NightLightState.maxTemperature - NightLightState.minTemperature)),
              adjust: (d) => NightLightState.setTemperature(NightLightState.temperature + (d > 0 ? 100 : -100)),
              run: () => NightLightState.active = !NightLightState.active },
        ]
        if (BrightnessState.available) out.push(
            { kind: "level", group: "settings", key: "set:brightness", title: "Brightness", glyph: "\u{e1ac}",
              aliases: "screen backlight display dim",
              value: () => BrightnessState.value,
              set: (v) => BrightnessState.set(v), adjust: (d) => BrightnessState.set(BrightnessState.value + d) })

        // power mode: one choice per profile
        const profiles = [PowerProfile.PowerSaver, PowerProfile.Balanced]
        if (PowerProfiles.hasPerformanceProfile) profiles.push(PowerProfile.Performance)
        for (const p of profiles) out.push(
            { kind: "choice", group: "power mode", key: "set:power", title: "Power mode: " + profileName(p), glyph: "\u{eaf6}",
              aliases: "power profile battery performance saver",
              on: () => PowerProfiles.profile === p, run: () => PowerProfiles.profile = p })

        // outputs and inputs: one choice each, on the default
        for (const s of VolumeState.sinks) out.push(
            { kind: "choice", group: "output", key: "set:output", title: "Output: " + VolumeState.nodeName(s), glyph: "\u{e32d}",
              aliases: "out sound device speaker headphones audio",
              on: () => Pipewire.defaultAudioSink === s, run: () => VolumeState.setSink(s) })
        for (const s of VolumeState.sources) out.push(
            { kind: "choice", group: "input", key: "set:input", title: "Input: " + VolumeState.nodeName(s), glyph: "\u{e31d}",
              aliases: "in mic microphone device",
              on: () => Pipewire.defaultAudioSource === s, run: () => VolumeState.setSource(s) })

        // the headset's codecs, when the output is bluetooth
        for (const mode of ["music", "call"]) for (const c of VolumeState.codecs(outCard, mode)) out.push(
            { kind: "choice", group: "codec", key: "set:codec", title: "Codec: " + c.codec + (mode === "call" ? " (call)" : ""), glyph: "\u{e60f}",
              aliases: "bluetooth codec aac aptx sbc ldac quality headset",
              on: () => VolumeState.activeCodec(root.outCard) === c.codec + (mode === "call" ? " (call)" : ""),
              run: () => VolumeState.setProfile(root.outCard, c.profile) })

        // screen layouts
        for (const l of RiceState.layouts) out.push(
            { kind: "choice", group: "layout", key: "set:layout", title: "Layout: " + l, glyph: "\u{e30c}",
              aliases: "display screen monitor mirror hdmi",
              on: () => RiceState.currentLayout === l, run: () => RiceState.applyLayout(l) })

        // the console's pages
        for (const [page, title, aliases] of [["quick", "quick settings", "control panel overview"],
                                              ["sound", "sound settings", "audio mixer devices apps"],
                                              ["network", "network settings", "wifi vpn interfaces ip"],
                                              ["bluetooth", "bluetooth settings", "devices pair scan"],
                                              ["notifications", "notifications", "unread history"]]) out.push(
            { kind: "action", group: "page", key: "set:page:" + page, title: title, glyph: "\u{e5cc}",
              aliases: aliases, keepOpen: true, run: () => root.openPage(page) })
        return out
    }
}
