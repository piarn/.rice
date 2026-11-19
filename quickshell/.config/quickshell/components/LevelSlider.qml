// Hand-rolled drag/click level slider (0..1): a thin track, the filled
// part in the accent (red while muted), and a square knob. No
// QtQuick.Controls elsewhere in this shell, so a themed Slider would mean
// fighting its default style. Emits moved(v) while dragging and
// stepped(±step) on the wheel; the owner writes it wherever it belongs
// (wpctl, backlight).
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
    readonly property color fill: root.muted ? Colors.red : Colors.neon

    // a thin track, filled in the accent; the knob only shows while hovered
    // or dragged, so a column of sliders reads as quiet lines
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: Style.round
        color: Style.tint(Colors.fg, 0.10)

        Rectangle {
            width: track.width * root.shown
            height: parent.height
            radius: Style.round
            color: root.fill
            opacity: 0.85
        }
    }

    Rectangle {
        id: knob
        visible: mouse.containsMouse || mouse.pressed
        width: 10
        height: 10
        radius: Style.round
        x: Math.max(0, Math.min(root.width - width, root.width * root.shown - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.fg
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
