// Quick tab tile: icon, title and subtitle on a quiet tile. While `active`
// the icon turns the accent and a faint accent tint sits behind it; nothing
// else changes colour. Clicking the tile toggles; the optional › on the
// right opens the feature's own tab (`detail`). Laid out in a grid with a
// gap.
import QtQuick
import quickshell

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasDetail: false
    signal toggled()
    signal detail()

    implicitHeight: 52
    radius: Style.round
    color: Style.tint(Colors.fg, mouse.containsMouse ? 0.08 : 0.04)

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: Style.round
        color: root.active ? Style.tint(Colors.neon, 0.18) : "transparent"

        Icon {
            anchors.centerIn: parent
            font.pixelSize: 16
            color: root.active ? Colors.neon : Colors.gray
            text: root.icon
        }
    }

    Column {
        anchors.left: badge.right
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        MonoText {
            width: parent.width
            elide: Text.ElideRight
            color: root.active ? Colors.fg : Colors.gray2
            text: root.title.toLowerCase()
        }
        MonoText {
            width: parent.width
            visible: text !== ""
            font.pixelSize: 11
            elide: Text.ElideRight
            color: Colors.gray
            text: root.subtitle
        }
    }

    Rectangle {
        id: chevron
        visible: root.hasDetail
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: parent.height - 12
        radius: Style.round
        color: chevronMouse.containsMouse ? Style.tint(Colors.fg, 0.10) : "transparent"

        Icon {
            anchors.centerIn: parent
            font.pixelSize: 16
            color: chevronMouse.containsMouse ? Colors.fg : Colors.gray2
            text: "\u{e5cc}"   // chevron_right
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detail()
        }
    }
}
