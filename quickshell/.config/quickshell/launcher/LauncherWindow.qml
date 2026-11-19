// One screen's launcher window: the run box ($mod+d) floating in the middle
// of the screen, a quarter of the way down, so its search field stays put
// while the list under it grows and shrinks. Adopts the shared Launcher the
// way the island and the side panel adopt theirs.
//
// Holds the keyboard while open (it's a text box), sits on the overlay
// layer, and a transparent catcher over every screen closes it on a click
// outside, like the other surfaces.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: win

    required property var modelData
    required property Item launcher

    readonly property bool openHere: IslandState.launcherOpen && IslandState.screen === modelData

    screen: modelData
    visible: openHere
    // anchored to the top only, so it's centred left to right
    anchors.top: true
    margins.top: Math.round((modelData ? modelData.height : 1080) * 0.24)
    implicitWidth: 640
    implicitHeight: frame.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: openHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Variants {
        model: win.openHere ? Quickshell.screens : []

        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-clickaway"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: IslandState.close()
            }
        }
    }

    onOpenHereChanged: if (openHere) Qt.callLater(launcher.focusCurrent)

    Rectangle {
        id: frame
        width: win.width
        height: win.launcher.implicitHeight + 2 * Style.pad
        color: Colors.mantle
        radius: Style.radius
        border.width: Style.border
        border.color: Colors.surface

        Item {
            id: holder
            x: Style.pad
            y: Style.pad
            width: parent.width - 2 * Style.pad
            height: win.launcher.implicitHeight
        }
    }

    Binding {
        target: win.launcher
        property: "parent"
        value: holder
        when: win.openHere
    }
    Binding {
        target: win.launcher
        property: "width"
        value: holder.width
        when: win.openHere
    }
}
