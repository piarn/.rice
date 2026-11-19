// A readout section's title: spaced capitals in grey, a faint rule running
// to the right, and the section's actions (TextButtons, as children) at the
// end of the rule. The space above it is the section gap.
//
//   NETWORK · 2 ─────────────────────────────── reload  settings
import QtQuick
import quickshell

Item {
    id: header

    property string title: ""
    property string count: ""
    default property alias actions: actionRow.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(label.implicitHeight, actionRow.implicitHeight) + topGap
    // the section gap, on top; 0 for the first section of a page
    property int topGap: Style.sectionGap - 10

    MonoText {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: Style.inset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (Math.max(label.implicitHeight, actionRow.implicitHeight) - label.implicitHeight) / 2
        font.letterSpacing: Style.labelSpacing
        color: Colors.gray
        text: header.title.toUpperCase() + (header.count !== "" ? " · " + header.count : "")
    }

    Rectangle {
        anchors.left: label.right
        anchors.right: actionRow.left
        anchors.leftMargin: 10
        anchors.rightMargin: actionRow.width > 0 ? 10 : 0
        anchors.verticalCenter: label.verticalCenter
        height: 1
        color: Colors.surface
    }

    // lines up with the rows' last column below (Style.inset)
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: Style.inset
        anchors.verticalCenter: label.verticalCenter
        spacing: 6
    }
}
