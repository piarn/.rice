// One row of a Quiet page: the label on the left, the value on the right,
// and nothing in between.
//
//   Wi-Fi                                         azh  48%
//
// On/off reads from colour alone (`light`: true/false, or undefined when the
// row doesn't switch): on, the label and value are white; off, the value is
// dim. A row that opens something (`opens`) shows a faint › only while
// hovered or selected.
//
// Left click / Space: toggle (or open, for rows without on/off). Right click
// / Enter: open (or `chevronClicked` with splitChevron, e.g. forget a saved
// network). `key` is the page key that acts on it, listed by `?`.
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
    property bool splitChevron: false

    signal toggled()
    signal opened()
    signal chevronClicked()

    readonly property bool consoleRow: true
    readonly property bool hasLight: light === true || light === false
    function activate() { if (hasLight) toggled(); else opened() }
    function secondary() { if (splitChevron) chevronClicked(); else if (opens) opened(); else activate() }
    function adjust(delta) {}

    readonly property bool lit: light === true
    readonly property bool hot: selected || mouse.containsMouse

    width: parent ? parent.width : 0
    implicitHeight: Style.rowHeight

    Rectangle {
        anchors.fill: parent
        color: row.selected ? Style.tint(Colors.fg, 0.06)
            : mouse.containsMouse ? Style.tint(Colors.fg, 0.035) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.fast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.dim
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => m.button === Qt.RightButton ? row.secondary() : row.activate()
    }

    // the label gets what the value leaves, shortened with … if it has to
    MonoText {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: Style.inset + row.indent
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width - Style.inset * 2 - row.indent - valueText.width - chevron.width - 24)
        elide: Text.ElideRight
        color: row.dim ? Colors.dim : row.lit ? Colors.fg : row.labelColor
        text: row.label
    }

    MonoText {
        id: valueText
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width * 0.5)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        color: row.dim ? Colors.dim
            : row.light === false ? Colors.gray
            : row.opens && row.hot ? Colors.fg : row.valueColor
        text: row.value === "on" ? "On" : row.value === "off" ? "Off" : row.value
    }

    // a faint ›, only while it would mean something
    MonoText {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Style.inset
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        horizontalAlignment: Text.AlignRight
        opacity: row.opens && row.hot ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.fast } }
        color: Colors.gray
        text: "›"
    }
}
