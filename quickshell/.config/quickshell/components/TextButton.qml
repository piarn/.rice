// A plain text button: just the word, grey, brightening on hover. Colour
// only where it means something: `baseColor` red for a destructive action,
// amber for something in progress; the old default action colour reads as
// plain grey like the rest. Set the inherited `enabled` to false to dim it.
import QtQuick
import quickshell

Text {
    id: root
    property string label: ""
    property color baseColor: Colors.acid
    signal clicked()

    // the old pink "action" colour, and the plain greys, are just grey now
    readonly property color tone: Qt.colorEqual(baseColor, Colors.acid) || Qt.colorEqual(baseColor, Colors.gray2)
        ? Colors.gray2 : baseColor

    font.family: Style.font
    // hinted, unsmoothed edges: a pixel font stays on its pixels
    renderType: Text.NativeRendering
    font.pixelSize: Style.fontSize
    text: label
    topPadding: 4
    bottomPadding: 4
    color: !enabled ? Colors.dim : mouse.containsMouse ? Colors.fg : root.tone
    Behavior on color { ColorAnimation { duration: Style.fast } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
