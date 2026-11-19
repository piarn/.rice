// One of the top row's corner pieces on one screen: the workspaces on the
// left, the status readout on the right (shell.qml). No box: its one child
// floats on the wallpaper and sets the size. Like the island, it moves to
// the overlay layer while anything is open, so it stays clickable above the
// click-away catcher, and it never takes the keyboard.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: card

    required property var modelData
    property bool rightSide: false
    default property alias content: inner.data

    screen: modelData
    anchors.top: true
    anchors.left: !rightSide
    anchors.right: rightSide
    margins.top: 6
    margins.left: 8
    margins.right: 8
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: Math.max(1, inner.childrenRect.width)
    implicitHeight: Style.barHeight
    WlrLayershell.namespace: "quickshell-card"
    WlrLayershell.layer: IslandState.grown ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        id: inner
        width: childrenRect.width
        height: Style.barHeight
    }
}
