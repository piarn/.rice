// The control panel's sound tab. Opened from the strip's volume or mic icon
// (or `qs ipc call popup toggle sound`). Sections:
//  - output / input: every device with its own volume and mute; click a
//    device's name to make it the default (marked). The icon mutes, middle
//    click too, the wheel steps. A bluetooth output shows its codec in use,
//    and its music / call codecs to switch between (components/CodecPicker).
//  - apps: what's playing, each with its volume and mute, and [→ device]
//    to move it to another output
//  - recording: apps using a microphone right now
//  - profiles: each built-in sound card's mode — HDMI on or off, analog
//    stereo or pro audio — click to switch
// [mixer] opens pulsemixer in a terminal for anything deeper.
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

    // the app stream whose output list is open, and the card whose profiles are
    property string movingStream: ""
    property string openCard: ""
    // the profiles section: sound cards that aren't bluetooth (those get
    // their codecs under their output instead)
    readonly property var wiredCards: VolumeState.cards.filter(c => c.address === "")

    onOpened: {
        movingStream = ""
        openCard = ""
        VolumeState.refreshExtras()
    }

    // live volumes for every device and app, only while this tab is open
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

    // A device: its name (click: make it the default), then its level.
    component DeviceRow: Column {
        id: dev
        required property var modelData
        property bool input: false
        readonly property var node: modelData
        readonly property var audio: node ? node.audio : null
        readonly property bool isDefault: node === (input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink)

        width: menu.innerWidth
        spacing: 2

        Rectangle {
            width: parent.width
            height: 22
            radius: Style.round
            color: nameMouse.containsMouse && !dev.isDefault ? Style.tint(Colors.fg, 0.05) : "transparent"

            Marker { visible: dev.isDefault }

            MonoText {
                anchors.left: parent.left
                anchors.right: defaultLabel.left
                anchors.leftMargin: Style.inset
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                color: dev.isDefault ? Colors.fg : Colors.gray2
                text: VolumeState.nodeName(dev.node)
            }
            MonoText {
                id: defaultLabel
                anchors.right: parent.right
                anchors.rightMargin: Style.inset
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 11
                color: dev.isDefault ? Colors.gray2 : nameMouse.containsMouse ? Colors.fg : Colors.gray
                text: dev.isDefault ? "default" : "make default"
            }
            MouseArea {
                id: nameMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: dev.isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!dev.isDefault) dev.input ? VolumeState.setSource(dev.node) : VolumeState.setSink(dev.node)
            }
        }

        LevelRow {
            width: parent.width
            icon: menu.deviceIcon(dev.node, dev.input)
            value: dev.audio ? dev.audio.volume : 0
            muted: dev.audio ? dev.audio.muted : false
            onMoved: (v) => VolumeState.setNodeVolume(dev.node, v)
            onStepped: (d) => VolumeState.adjustNode(dev.node, d)
            onToggled: VolumeState.toggleNodeMute(dev.node)
        }

        // a bluetooth output: its codecs, lined up under the slider
        CodecPicker {
            readonly property var btCard: !dev.input && (dev.node.name || "").startsWith("bluez")
                ? VolumeState.cardFor(dev.node) : null
            x: 20
            width: parent.width - 20 - Style.inset
            topPadding: 2
            card: btCard
        }
    }

    // An app's stream: name, what it plays, its level, and where it plays to.
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
        spacing: 2

        Item {
            width: parent.width
            height: Math.max(titleCol.implicitHeight, 22)

            Column {
                id: titleCol
                anchors.left: parent.left
                anchors.right: moveBtn.visible ? moveBtn.left : parent.right
                anchors.leftMargin: Style.inset
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                MonoText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: VolumeState.streamTitle(stream.node)
                }
                MonoText {
                    width: parent.width
                    visible: text !== ""
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Colors.gray2
                    text: VolumeState.streamDetail(stream.node)
                }
            }

            TextButton {
                id: moveBtn
                anchors.right: parent.right
                anchors.rightMargin: Style.inset
                anchors.verticalCenter: parent.verticalCenter
                visible: stream.canMove
                width: Math.min(implicitWidth, menu.innerWidth * 0.45)
                elide: Text.ElideRight
                label: "→ " + (stream.sink ? VolumeState.nodeName(stream.sink) : "?")
                baseColor: stream.moving ? Colors.neon : Colors.gray2
                onClicked: menu.movingStream = stream.moving ? "" : String(stream.node.id)
            }
        }

        LevelRow {
            width: parent.width
            icon: stream.recording ? "\u{e31d}" : "\u{e405}"   // mic / music_note
            value: stream.audio ? stream.audio.volume : 0
            muted: stream.audio ? stream.audio.muted : false
            onMoved: (v) => VolumeState.setNodeVolume(stream.node, v)
            onStepped: (d) => VolumeState.adjustNode(stream.node, d)
            onToggled: VolumeState.toggleNodeMute(stream.node)
        }

        // where to send it
        Repeater {
            model: stream.moving ? VolumeState.sinks : []

            delegate: Rectangle {
                id: target
                required property var modelData
                readonly property bool current: modelData.id === stream.sinkId
                width: stream.width
                height: 24
                radius: Style.round
                color: targetMouse.containsMouse ? Style.tint(Colors.fg, 0.05) : "transparent"

                Marker { visible: target.current }

                Icon {
                    id: targetIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 14
                    color: target.current ? Colors.neon : Colors.gray2
                    text: menu.deviceIcon(target.modelData, false)
                }
                MonoText {
                    anchors.left: targetIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: Style.inset
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    color: target.current ? Colors.fg : Colors.gray2
                    text: VolumeState.nodeName(target.modelData)
                }
                MouseArea {
                    id: targetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        VolumeState.moveStream(stream.node, target.modelData)
                        menu.movingStream = ""
                    }
                }
            }
        }
    }

    // output
    SectionHeader {
        title: "output"
        count: String(VolumeState.sinks.length)

        TextButton {
            label: "mixer"
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

    Divider {}

    // input
    SectionHeader {
        title: "input"
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

    Divider {}

    // apps
    SectionHeader {
        title: "apps"
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

    // apps using a mic
    Divider { visible: VolumeState.recording.length > 0 }

    SectionHeader {
        visible: VolumeState.recording.length > 0
        title: "recording"
        count: String(VolumeState.recording.length)
    }

    Repeater {
        model: VolumeState.recording
        delegate: StreamRow { recording: true }
    }

    Divider { visible: menu.wiredCards.length > 0 }

    // card profiles
    SectionHeader {
        visible: menu.wiredCards.length > 0
        title: "profiles"
    }

    Repeater {
        model: menu.wiredCards

        delegate: Column {
            id: card
            required property var modelData
            readonly property bool open: menu.openCard === modelData.name
            readonly property var activeProfile: modelData.profiles.find(p => p.name === modelData.active) || null
            width: menu.innerWidth
            spacing: 2

            Rectangle {
                width: parent.width
                height: cardCol.implicitHeight + 8
                radius: Style.round
                color: cardMouse.containsMouse ? Style.tint(Colors.fg, 0.05) : "transparent"

                Column {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.right: chevron.left
                    anchors.leftMargin: Style.inset
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    MonoText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.modelData.description
                    }
                    MonoText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: card.modelData.active === "off" ? Colors.gray : Colors.gray2
                        text: card.activeProfile ? card.activeProfile.description : card.modelData.active
                    }
                }

                Icon {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: Style.inset
                    anchors.verticalCenter: parent.verticalCenter
                    color: card.open ? Colors.neon : Colors.gray2
                    text: card.open ? "\u{e5ce}" : "\u{e5cf}"   // expand_less / expand_more
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.openCard = card.open ? "" : card.modelData.name
                }
            }

            Repeater {
                model: card.open ? card.modelData.profiles : []

                delegate: Rectangle {
                    id: profileRow
                    required property var modelData
                    readonly property bool current: modelData.name === card.modelData.active
                    width: card.width
                    height: 24
                    radius: Style.round
                    color: profileMouse.containsMouse ? Style.tint(Colors.fg, 0.05) : "transparent"

                    Marker { visible: profileRow.current }

                    MonoText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 20
                        anchors.rightMargin: Style.inset
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        color: profileRow.current ? Colors.fg : Colors.gray2
                        text: profileRow.modelData.description
                    }
                    MouseArea {
                        id: profileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VolumeState.setProfile(card.modelData, profileRow.modelData.name)
                    }
                }
            }
        }
    }
}
