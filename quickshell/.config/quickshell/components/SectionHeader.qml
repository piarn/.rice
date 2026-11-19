// A group's label on a Quiet page: small grey text above the group, with
// its actions (TextButtons, as children) on the right. No rule: the space
// above it (Style.groupGap) is what separates groups. Leave `title` empty
// for a group that needs no name.
import QtQuick
import quickshell

Item {
    id: header

    property string title: ""
    property string count: ""
    default property alias actions: actionRow.data

    width: parent ? parent.width : 0
    // the gap above; 0 for a page's first group
    property int topGap: Style.groupGap - 6
    // untitled and without actions it is just the space between groups
    readonly property bool named: title !== "" || actionRow.children.length > 0
    implicitHeight: (named ? Math.max(label.implicitHeight, actionRow.implicitHeight, 18) : 0) + topGap

    MonoText {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: Style.inset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        color: Colors.gray
        text: header.title !== "" ? header.title.charAt(0).toUpperCase() + header.title.slice(1)
            + (header.count !== "" ? "  " + header.count : "") : ""
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: Style.inset
        anchors.verticalCenter: label.verticalCenter
        spacing: 14
    }
}
