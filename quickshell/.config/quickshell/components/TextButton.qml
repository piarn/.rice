// A small chip button: the label on a quiet neutral fill, a little brighter
// on hover. Colour only where it means something: `baseColor` red for a
// destructive or "off" action, amber for in-progress, grey for secondary;
// the default action colour reads as plain text. Every tab's actions use it.
// Set the inherited `enabled` to false to grey it out.
import QtQuick
import quickshell

Text {
    id: root
    property string label: ""
    property color baseColor: Colors.acid
    signal clicked()

    // the old pink "action" colour is just the normal text colour now
    readonly property color tone: Qt.colorEqual(baseColor, Colors.acid) ? Colors.fg : baseColor

    font.family: Style.font
    // hinted, unsmoothed edges: a pixel font stays on its pixels
    renderType: Text.NativeRendering
    font.pixelSize: 11
    text: label
    leftPadding: 9
    rightPadding: 9
    topPadding: 4
    bottomPadding: 4
    color: !enabled ? Colors.gray : root.tone

    Rectangle {
        z: -1
        anchors.fill: parent
        radius: Style.round
        color: Style.tint(Colors.fg, !root.enabled ? 0.03 : mouse.containsMouse ? 0.12 : 0.06)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
