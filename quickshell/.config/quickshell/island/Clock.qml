// The top row's center: date and time, YYYY-MM-DD HH:MM:SS, floating on the
// wallpaper (the island's card only appears once it grows). Click: the
// calendar.
import QtQuick
import quickshell
import "../state"
import "../components"

Item {
    id: root

    required property var screen
    readonly property string format: "yyyy-MM-dd HH:mm:ss"

    implicitWidth: clock.implicitWidth + 2 * Style.pad
    implicitHeight: Style.barHeight

    MonoText {
        id: clock
        anchors.centerIn: parent
        font.pixelSize: Style.fontSize
        color: mouse.containsMouse || (IslandState.tab === "calendar" && IslandState.screen === root.screen) ? Colors.fg : Colors.gray2
        text: Qt.formatDateTime(new Date(), root.format)

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), root.format)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IslandState.toggle("calendar", root.screen)
    }
}
