// A level in the readout: label (or an icon), a thin slider, the number,
// and the dim key — lined up with ReadoutRow's columns:
//
//   volume   ━━━━━━━━━━━━━━━──────────────   37      v
//
// Click/drag/wheel on the slider sets it; clicking the label or icon, or a
// middle click anywhere, emits toggled (mute for audio). The optional
// chevron in front (`expandable`) emits expandClicked. In a page's keyboard
// order (island/Tab.qml): Space/Enter toggle, h/l step it.
import QtQuick
import quickshell

Item {
    id: root

    property string label: ""
    property string icon: ""
    property real value: 0
    property bool muted: false
    property bool expandable: false
    property bool expanded: false
    property string expandGlyph: "\u{e5cf}"
    // the number on the right: 0–100, "muted" while muted, unless the owner
    // says otherwise
    property string valueText: muted ? "muted" : String(Math.round(value * 100))
    property string key: ""
    property bool selected: false
    signal moved(real v)
    signal stepped(real delta)
    signal toggled()
    signal expandClicked()

    readonly property bool consoleRow: true
    function activate() { toggled() }
    function adjust(delta) { stepped(delta > 0 ? 0.05 : -0.05) }

    width: parent ? parent.width : 0
    height: Style.rowHeight

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Style.tint(Colors.fg, 0.07) : "transparent"
    }
    Marker { visible: root.selected }

    // Middle clicks only; left clicks/drags belong to the slider on top.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.toggled()
    }

    Icon {
        id: chevron
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        visible: root.expandable
        font.pixelSize: 14
        color: root.expanded || chevronMouse.containsMouse ? Colors.fg : Colors.gray
        text: root.expandGlyph
        rotation: root.expanded ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Style.fast } }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandClicked()
        }
    }

    // the label (or icon): click mutes
    Item {
        id: lead
        anchors.left: parent.left
        anchors.leftMargin: root.expandable ? 20 : Style.inset
        anchors.verticalCenter: parent.verticalCenter
        width: root.label !== "" ? 88 : 22
        height: parent.height

        MonoText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            color: root.muted ? Colors.red : Colors.gray2
            text: root.label
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label === ""
            font.pixelSize: 16
            color: root.muted ? Colors.red : Colors.gray2
            text: root.icon
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }

    LevelSlider {
        anchors.left: lead.right
        anchors.right: number.left
        anchors.leftMargin: 6
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        muted: root.muted
        onMoved: (v) => root.moved(v)
        onStepped: (d) => root.stepped(d)
    }

    MonoText {
        id: number
        anchors.right: keyHint.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        horizontalAlignment: Text.AlignRight
        color: root.muted ? Colors.red : Colors.fg
        text: root.valueText
    }

    // the same right edge as ReadoutRow: its light and › columns sit where
    // the number is, so the key lines up
    KeyHint {
        id: keyHint
        anchors.right: parent.right
        anchors.rightMargin: Style.inset
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        horizontalAlignment: Text.AlignRight
        key: root.key
        bright: root.selected
    }
}
