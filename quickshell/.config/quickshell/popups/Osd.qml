// Volume / mic / brightness OSD, in the console's readout style: a slim
// card low in the middle of the focused screen —
//
//   VOLUME   ━━━━━━━━━━━━━━━━━━━━━──────────────   37
//
// Click-through (empty input mask), never takes focus, fades out 1.5s after
// the last change. What it shows comes from state/OsdState.qml.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: root

    readonly property real level: OsdState.muted ? 0 : Math.max(0, Math.min(1, OsdState.value))

    visible: card.opacity > 0
    screen: OsdState.screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors.bottom: true
    margins.bottom: screen ? Math.round(screen.height * 0.12) : 120
    implicitWidth: 360
    implicitHeight: 40
    mask: Region {}

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Style.radius
        color: Style.tint(Colors.mantle, 0.96)
        border.width: Style.border
        border.color: Colors.surface
        opacity: OsdState.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: OsdState.shown ? Style.fast : 300; easing.type: Easing.OutQuad } }

        MonoText {
            id: label
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 92
            font.letterSpacing: Style.labelSpacing
            color: Colors.gray
            text: (OsdState.kind || "volume").toUpperCase()
        }

        Rectangle {
            id: track
            anchors.left: label.right
            anchors.right: number.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            color: Style.tint(Colors.fg, 0.10)

            Rectangle {
                width: track.width * root.level
                height: parent.height
                color: Colors.neon
                opacity: 0.85
                Behavior on width { NumberAnimation { duration: Style.fast } }
            }
        }

        MonoText {
            id: number
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            horizontalAlignment: Text.AlignRight
            color: OsdState.muted ? Colors.red : Colors.fg
            text: OsdState.muted ? "muted" : String(Math.round(Math.min(1, OsdState.value) * 100))
        }
    }
}
