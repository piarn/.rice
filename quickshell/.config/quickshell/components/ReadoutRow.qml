// One line of the console's readout:
//
//   label ............................ value   ■  ›  w
//
// The label on the left, a dotted leader, the value on the right, then three
// fixed columns so every row lines up: a light for things that switch on and
// off (`light`: true/false; leave it undefined for none), › for rows that
// open something (`opens`), and the dim key that acts on it (`key`).
//
// Click: toggles a row with a light, opens one without; the › always opens.
// In a page's keyboard order (island/Tab.qml): Space/Enter run activate(),
// and the page's own key map handles `key`.
import QtQuick
import quickshell

Item {
    id: row

    property string label: ""
    property string value: ""
    property color valueColor: Colors.fg
    property var light: undefined
    property bool opens: false
    property string key: ""
    property bool selected: false
    // greyed out, e.g. no adapter
    property bool dim: false
    // extra left margin, for a row that belongs to the one above it
    property int indent: 0
    property color labelColor: Colors.gray2

    signal toggled()
    signal opened()
    // with splitChevron the › emits its own signal instead of opened(), for
    // rows where a click does one thing and the › another
    property bool splitChevron: false
    signal chevronClicked()

    readonly property bool consoleRow: true
    readonly property bool hasLight: light === true || light === false
    function activate() { if (hasLight) toggled(); else opened() }
    function adjust(delta) {}

    width: parent ? parent.width : 0
    implicitHeight: Style.rowHeight

    Rectangle {
        anchors.fill: parent
        color: row.selected ? Style.tint(Colors.fg, 0.07)
            : mouse.containsMouse ? Style.tint(Colors.fg, 0.04) : "transparent"
    }
    Marker { visible: row.selected }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !row.dim
        onClicked: row.activate()
    }

    // label and value share the line: the value keeps up to 45% of it, the
    // label gets the rest, each shortened with … if it has to
    MonoText {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: Style.inset + row.indent
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width - Style.inset * 2 - row.indent - cols.width - 26 - valueText.width)
        elide: Text.ElideRight
        color: row.dim ? Colors.dim : row.labelColor
        text: row.label
    }

    // the dotted leader: pixel dots every 6px, from the label to the value
    Item {
        id: leader
        anchors.left: labelText.right
        anchors.right: valueText.left
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 3
        height: 2
        clip: true

        Row {
            spacing: 4
            Repeater {
                model: Math.max(0, Math.floor(leader.width / 6))
                delegate: Rectangle { width: 2; height: 2; color: Colors.surface }
            }
        }
    }

    MonoText {
        id: valueText
        anchors.right: cols.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width * 0.45)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        color: row.dim ? Colors.dim : row.valueColor
        text: row.value
    }

    // light · › · key, fixed widths so every row's columns line up
    Row {
        id: cols
        anchors.right: parent.right
        anchors.rightMargin: Style.inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Item {
            width: 10
            height: Style.rowHeight
            Light {
                anchors.centerIn: parent
                visible: row.hasLight
                on: row.light === true
            }
        }
        Item {
            width: 10
            height: Style.rowHeight
            MonoText {
                anchors.centerIn: parent
                visible: row.opens
                color: openMouse.containsMouse ? Colors.fg : Colors.gray
                text: "›"
            }
            MouseArea {
                id: openMouse
                anchors.fill: parent
                anchors.margins: -3
                visible: row.opens
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.splitChevron ? row.chevronClicked() : row.opened()
            }
        }
        KeyHint {
            width: 10
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            key: row.key
            bright: row.selected
        }
    }
}
