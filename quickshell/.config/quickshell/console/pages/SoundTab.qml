// The console's sound page. Opened from the top row's volume or mic, or
// `qs ipc call popup toggle sound`. As readout rows:
//   OUTPUT / INPUT  every device: its name with the light on the default
//                   (click another to make it the default), its level
//                   under it (click the icon or middle click: mute; wheel
//                   steps). A bluetooth output also shows `codec ... aptX HD ›`,
//                   opening its music / call codecs (components/CodecPicker).
//   APPS            what's playing, its level, and › to move it to another
//                   output
//   RECORDING       apps using a microphone right now
//   PROFILES        each built-in sound card's mode (HDMI on/off, analog or
//                   pro audio); › lists them
// `mixer` opens pulsemixer in a terminal for anything deeper.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import quickshell
import "../../state"
import "../../components"
import "../../island"

Tab {
    id: menu
    name: "sound"

    // the app stream whose output list is open, the card whose profiles are,
    // the bluetooth output whose codecs are
    property string movingStream: ""
    property string openCard: ""
    property string openCodecs: ""
    // the profiles section: sound cards that aren't bluetooth (those get
    // their codecs under their output instead)
    readonly property var wiredCards: VolumeState.cards.filter(c => c.address === "")

    onOpened: {
        movingStream = ""
        openCard = ""
        openCodecs = ""
        VolumeState.refreshExtras()
    }

    // live volumes for every device and app, only while this page is open
    Binding {
        target: VolumeState
        property: "trackAll"
        value: menu.shown
    }

    function deviceIcon(node, input) {
        const n = (node.name || "").toLowerCase()
        if (input) return n.startsWith("bluez") || n.includes("headset") ? "\u{e311}" : "\u{e31d}"   // headset_mic / mic
        if (n.startsWith("bluez")) return "\u{e60f}"   // bluetooth_audio
        if (n.includes("hdmi") || n.includes("displayport")) return "\u{e333}"   // tv
        if (n.includes("headset") || n.includes("headphone")) return "\u{f01f}"   // headphones
        return "\u{e32d}"   // speaker
    }

    // A device: its name (■ the default; click to make it so), then its level.
    component DeviceRow: Column {
        id: dev
        required property var modelData
        property bool input: false
        readonly property var node: modelData
        readonly property var audio: node ? node.audio : null
        readonly property bool isDefault: node === (input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink)
        readonly property var btCard: !input && (node.name || "").startsWith("bluez") ? VolumeState.cardFor(node) : null
        readonly property bool codecsOpen: menu.openCodecs === String(node.id)

        width: menu.innerWidth
        spacing: 0

        ReadoutRow {
            id: nameRow
            label: VolumeState.nodeName(dev.node)
            labelColor: dev.isDefault ? Colors.fg : Colors.gray2
            value: dev.isDefault ? "default" : ""
            valueColor: Colors.gray
            light: dev.isDefault
            selected: menu.selectedRow === nameRow
            onToggled: if (!dev.isDefault) dev.input ? VolumeState.setSource(dev.node) : VolumeState.setSink(dev.node)
        }

        LevelRow {
            id: levelRow
            icon: menu.deviceIcon(dev.node, dev.input)
            value: dev.audio ? dev.audio.volume : 0
            muted: dev.audio ? dev.audio.muted : false
            selected: menu.selectedRow === levelRow
            onMoved: (v) => VolumeState.setNodeVolume(dev.node, v)
            onStepped: (d) => VolumeState.adjustNode(dev.node, d)
            onToggled: VolumeState.toggleNodeMute(dev.node)
        }

        // a bluetooth output: the codec in use, › for the others
        ReadoutRow {
            id: codecRow
            visible: dev.btCard !== null && VolumeState.codecs(dev.btCard, "music").length > 0
            indent: 30
            label: "Codec"
            value: VolumeState.activeCodec(dev.btCard) || "off"
            opens: true
            selected: menu.selectedRow === codecRow
            onOpened: menu.openCodecs = dev.codecsOpen ? "" : String(dev.node.id)
        }
        CodecPicker {
            visible: dev.codecsOpen && card !== null
            x: Style.inset + 30
            width: parent.width - x - Style.inset
            topPadding: 2
            bottomPadding: 4
            card: dev.btCard
        }
    }

    // An app's stream: its name and what it plays, › to move it, its level.
    component StreamRow: Column {
        id: stream
        required property var modelData
        property bool recording: false
        readonly property var node: modelData
        readonly property var audio: node ? node.audio : null
        readonly property int sinkId: VolumeState.sinkOf(node)
        readonly property var sink: VolumeState.sinks.find(s => s.id === sinkId) || null
        readonly property bool canMove: !recording && VolumeState.sinks.length > 1 && sinkId >= 0
        readonly property bool moving: menu.movingStream === String(node.id)

        width: menu.innerWidth
        spacing: 0

        ReadoutRow {
            id: appRow
            label: VolumeState.streamTitle(stream.node)
            labelColor: Colors.fg
            value: stream.canMove && stream.sink ? "→ " + VolumeState.nodeName(stream.sink)
                : VolumeState.streamDetail(stream.node)
            valueColor: Colors.gray2
            opens: stream.canMove
            selected: menu.selectedRow === appRow
            onOpened: menu.movingStream = stream.moving ? "" : String(stream.node.id)
        }

        LevelRow {
            id: appLevel
            icon: stream.recording ? "\u{e31d}" : "\u{e405}"   // mic / music_note
            value: stream.audio ? stream.audio.volume : 0
            muted: stream.audio ? stream.audio.muted : false
            selected: menu.selectedRow === appLevel
            onMoved: (v) => VolumeState.setNodeVolume(stream.node, v)
            onStepped: (d) => VolumeState.adjustNode(stream.node, d)
            onToggled: VolumeState.toggleNodeMute(stream.node)
        }

        // where to send it
        Repeater {
            model: stream.moving ? VolumeState.sinks : []

            delegate: ReadoutRow {
                id: target
                required property var modelData
                indent: 30
                label: VolumeState.nodeName(modelData)
                light: modelData.id === stream.sinkId
                selected: menu.selectedRow === target
                onToggled: {
                    VolumeState.moveStream(stream.node, target.modelData)
                    menu.movingStream = ""
                }
            }
        }
    }

    // ---- OUTPUT
    SectionHeader {
        title: "Output"
        count: String(VolumeState.sinks.length)
        topGap: 0

        TextButton {
            label: "Mixer"
            baseColor: Colors.gray2
            onClicked: {
                menu.close()
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/foot-lig", "pulsemixer"])
            }
        }
    }

    MonoText {
        visible: VolumeState.sinks.length === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "no output devices"
    }

    Repeater {
        model: VolumeState.sinks
        delegate: DeviceRow {}
    }

    // ---- INPUT
    SectionHeader {
        title: "Input"
        count: String(VolumeState.sources.length)
    }

    MonoText {
        visible: VolumeState.sources.length === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "no microphones"
    }

    Repeater {
        model: VolumeState.sources
        delegate: DeviceRow { input: true }
    }

    // ---- APPS
    SectionHeader {
        title: "Apps"
        count: VolumeState.playback.length ? String(VolumeState.playback.length) : ""
    }

    MonoText {
        visible: VolumeState.playback.length === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "nothing is playing"
    }

    Repeater {
        model: VolumeState.playback
        delegate: StreamRow {}
    }

    // ---- RECORDING: apps using a mic
    SectionHeader {
        visible: VolumeState.recording.length > 0
        title: "Recording"
        count: String(VolumeState.recording.length)
    }

    Repeater {
        model: VolumeState.recording
        delegate: StreamRow { recording: true }
    }

    // ---- PROFILES
    SectionHeader {
        visible: menu.wiredCards.length > 0
        title: "Profiles"
    }

    Repeater {
        model: menu.wiredCards

        delegate: Column {
            id: card
            required property var modelData
            readonly property bool open: menu.openCard === modelData.name
            readonly property var activeProfile: modelData.profiles.find(p => p.name === modelData.active) || null
            width: menu.innerWidth
            spacing: 0

            ReadoutRow {
                id: cardRow
                label: card.modelData.description
                value: card.activeProfile ? card.activeProfile.description : card.modelData.active
                valueColor: card.modelData.active === "off" ? Colors.gray : Colors.gray2
                opens: true
                selected: menu.selectedRow === cardRow
                onOpened: menu.openCard = card.open ? "" : card.modelData.name
            }

            Repeater {
                model: card.open ? card.modelData.profiles : []

                delegate: ReadoutRow {
                    id: profileRow
                    required property var modelData
                    indent: 30
                    label: modelData.description
                    light: modelData.name === card.modelData.active
                    selected: menu.selectedRow === profileRow
                    onToggled: VolumeState.setProfile(card.modelData, profileRow.modelData.name)
                }
            }
        }
    }
}
