// Hand-rolled drag/click level slider (0..1): a 2px line, the filled part
// in the accent (red while muted), no knob. The fill glides to a new value
// (Style.fast) except while dragged, when it follows the pointer exactly.
// Emits moved(v) while dragging and stepped(±step) on the wheel; the owner
// writes it wherever it belongs (wpctl, backlight).
import QtQuick
import quickshell

Item {
    id: root
    property real value: 0
    property bool muted: false
    signal moved(real v)
    // wheel: ±step, applied relative to the owner's own latest target — the
    // bound value can trail behind rapid scrolling
    signal stepped(real delta)
    property real step: 0.05

    implicitWidth: 160
    implicitHeight: 14

    // While dragging, draw where the pointer is rather than the bound value,
    // which trails behind whatever process applies the change.
    property real dragValue: 0
    readonly property real shown: Math.max(0, Math.min(1, mouse.pressed ? dragValue : value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 2
        color: Style.tint(Colors.fg, mouse.containsMouse ? 0.16 : 0.10)

        Rectangle {
            height: parent.height
            width: track.width * root.shown
            color: root.muted ? Colors.red : Colors.neon
            Behavior on width {
                enabled: !mouse.pressed
                NumberAnimation { duration: Style.fast; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function emit(x) {
            root.dragValue = Math.max(0, Math.min(1, (x - 6) / root.width))
            root.moved(root.dragValue)
        }
        onPressed: (mouse) => emit(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) emit(mouse.x) }
        onWheel: (wheel) => root.stepped(wheel.angleDelta.y > 0 ? root.step : -root.step)
    }
}
