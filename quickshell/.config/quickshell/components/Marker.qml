// A short accent bar at a row's left edge — how the shell marks the
// selected or active row. Drop it into the row and bind `visible`.
import QtQuick
import quickshell

Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: 2
    anchors.verticalCenter: parent.verticalCenter
    width: Style.marker
    height: Math.max(10, parent.height * 0.55)
    radius: Style.round
    color: Colors.neon
}
