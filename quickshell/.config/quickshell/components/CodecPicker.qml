// A bluetooth audio device's codecs, for the sound and bluetooth tabs: one
// row of chips for music (A2DP: SBC, AAC, aptX, LDAC, ...) and one for calls
// (headset mode: CVSD, mSBC), each a card profile underneath
// (state/VolumeState.qml). The one in use is bright with the accent
// underline; clicking another switches to it, which takes the headset a
// second or two. Calls mode also turns on its microphone, at lower quality.
import QtQuick
import quickshell
import "../state"

Column {
    id: root

    property var card: null
    readonly property var music: VolumeState.codecs(card, "music")
    readonly property var call: VolumeState.codecs(card, "call")
    // the profile asked for, until the card reports it
    property string pending: ""

    visible: card !== null && (music.length > 0 || call.length > 0)
    spacing: 4

    onCardChanged: if (card && card.active === pending) pending = ""

    component CodecRow: Row {
        id: codecRow
        property string label: ""
        property var items: []
        visible: items.length > 0
        spacing: 8

        MonoText {
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 11
            color: Colors.gray
            text: codecRow.label
        }

        Flow {
            width: root.width - 52
            spacing: 4

            Repeater {
                model: codecRow.items

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool waiting: root.pending === modelData.profile
                    width: chipText.implicitWidth + 16
                    height: 22
                    radius: Style.round
                    color: Style.tint(Colors.fg, chipMouse.containsMouse && !modelData.active ? 0.10 : 0.05)

                    MonoText {
                        id: chipText
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        color: chip.modelData.active ? Colors.fg : chip.waiting ? Colors.amber
                            : chipMouse.containsMouse ? Colors.fg : Colors.gray2
                        text: chip.modelData.codec
                    }

                    Rectangle {
                        visible: chip.modelData.active
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: chipText.implicitWidth
                        height: 2
                        color: Colors.neon
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: chip.modelData.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (chip.modelData.active) return
                            root.pending = chip.modelData.profile
                            VolumeState.setProfile(root.card, chip.modelData.profile)
                        }
                    }
                }
            }
        }
    }

    CodecRow { label: "Music"; items: root.music }
    CodecRow { label: "Call"; items: root.call }
}
