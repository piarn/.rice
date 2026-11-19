// A level on a Quiet page: label (or an icon), a 2px line, the number — the
// number lined up with ReadoutRow's values:
//
//   Volume      ──────────────────────────────────        37
//
// Click/drag/wheel on the line sets it; clicking the label or icon, or a
// middle click anywhere, emits toggled (mute for audio). The optional
// chevron in front (`expandable`) emits expandClicked. In a page's keyboard
// order (island/Tab.qml): Space toggles, h/l step it.
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
    // the number: 0–100, "Muted" while muted, unless the owner says otherwise
    property string valueText: muted ? "Muted" : String(Math.round(value * 100))
    property string key: ""
    property bool selected: false
    signal moved(real v)
    signal stepped(real delta)
    signal toggled()
    signal expandClicked()

    readonly property bool consoleRow: true
    function activate() { toggled() }
    function secondary() { toggled() }
    function adjust(delta) { stepped(delta > 0 ? 0.05 : -0.05) }

    width: parent ? parent.width : 0
    height: Style.rowHeight

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Style.tint(Colors.fg, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.fast } }
    }

    // Middle clicks only; left clicks/drags belong to the line on top.
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
        anchors.leftMargin: root.expandable ? 22 : Style.inset
        anchors.verticalCenter: parent.verticalCenter
        width: root.label !== "" ? 100 : 22
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
            font.pixelSize: 15
            color: root.muted ? Colors.red : Colors.gray
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
        anchors.leftMargin: 4
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        muted: root.muted
        onMoved: (v) => root.moved(v)
        onStepped: (d) => root.stepped(d)
    }

    // the same right edge as ReadoutRow's values (inset + its › column)
    MonoText {
        id: number
        anchors.right: parent.right
        anchors.rightMargin: Style.inset + 14
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        color: root.muted ? Colors.red : Colors.fg
        text: root.valueText
    }
}
