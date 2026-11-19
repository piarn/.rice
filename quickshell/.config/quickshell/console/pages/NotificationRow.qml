// One notification in the notifications tab, laid out like the network
// tab's rows: image or app icon, summary, the body's first line, how long
// ago on the right, then its actions if it has any. Click runs the default
// action; [x] (on hover or selected) dismisses it. Critical ones get the
// red marker.
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import quickshell
import "../../state"
import "../../components"
import "../../island/format.js" as Fmt

Rectangle {
    id: row

    required property var notification
    property bool current: false
    // ticks the "3m" along
    property real now: Date.now()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var actions: NotificationState.visibleActions(notification)
    readonly property string imageSource: {
        const n = notification
        if (n.image) return n.image
        if (!n.appIcon) return ""
        if (n.appIcon.startsWith("/")) return "file://" + n.appIcon
        if (n.appIcon.includes("://")) return n.appIcon
        return Quickshell.iconPath(n.appIcon, true)
    }

    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight + 12
    color: current || mouse.containsMouse ? Style.tint(Colors.fg, 0.05) : "transparent"

    // only a critical notification gets a mark: red
    Marker {
        visible: row.critical
        color: Colors.red
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationState.invokeDefault(row.notification)
    }

    Item {
        id: iconBox
        x: 10
        y: 6
        width: 24
        height: 24

        Image {
            id: img
            anchors.fill: parent
            visible: row.imageSource !== "" && status !== Image.Error
            source: row.imageSource
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Icon {
            anchors.centerIn: parent
            visible: !img.visible
            font.pixelSize: 18
            color: Colors.gray2
            text: "\u{e7f4}"   // notifications
        }
    }

    Column {
        id: col
        anchors.left: iconBox.right
        anchors.leftMargin: 10
        anchors.right: side.left
        anchors.rightMargin: 8
        y: 6
        spacing: 2

        MonoText {
            width: parent.width
            elide: Text.ElideRight
            font.bold: true
            color: row.current ? Colors.fg : Colors.gray2
            text: row.notification.summary || row.notification.appName || "notification"
        }
        MonoText {
            visible: text !== ""
            width: parent.width
            elide: Text.ElideRight
            color: Colors.gray2
            textFormat: Text.PlainText
            text: (row.notification.body || "").split("\n")[0].replace(/<[^>]*>/g, "")
        }
        Row {
            visible: row.actions.length > 0
            spacing: 12
            topPadding: 2

            Repeater {
                model: row.actions
                TextButton {
                    required property var modelData
                    label: modelData.text
                    onClicked: modelData.invoke()
                }
            }
        }
    }

    Row {
        id: side
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 6
        spacing: 14

        MonoText {
            color: Colors.gray
            text: Fmt.ago(NotificationState.arrived[row.notification.id] || row.now, row.now)
        }
        TextButton {
            opacity: row.current || mouse.containsMouse ? 1 : 0
            label: "X"
            onClicked: NotificationState.dismiss(row.notification)
        }
    }
}
