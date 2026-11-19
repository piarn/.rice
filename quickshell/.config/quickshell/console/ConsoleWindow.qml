// One screen's console window: the console floating in the middle of the
// screen, a quarter of the way down, so its top line stays put while the
// page under it grows and shrinks. Adopts the shared Console the way the
// island adopts its Panel.
//
// Holds the keyboard while open, sits on the overlay layer, and a
// transparent catcher over every screen closes it on a click outside — the
// top row stays above that catcher, so its readout still switches pages.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: win

    required property var modelData
    required property Item panel

    readonly property bool openHere: IslandState.consoleOpen && IslandState.screen === modelData
    readonly property real screenHeight: modelData ? modelData.height : 1080

    screen: modelData
    visible: openHere
    // anchored to the top only, so it's centred left to right
    anchors.top: true
    margins.top: Math.round(screenHeight * 0.22)
    implicitWidth: Style.consoleWidth
    implicitHeight: frame.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-console"
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

    onOpenHereChanged: if (openHere) Qt.callLater(panel.focusCurrent)

    Rectangle {
        id: frame
        width: win.width
        height: win.panel.implicitHeight + 2 * Style.consolePad
        color: Colors.mantle
        radius: Style.radius
        border.width: Style.border
        border.color: Colors.surface

        Item {
            id: holder
            x: Style.consolePad
            y: Style.consolePad
            width: parent.width - 2 * Style.consolePad
            height: win.panel.implicitHeight
        }
    }

    Binding {
        target: win.panel
        property: "parent"
        value: holder
        when: win.openHere
    }
    Binding {
        target: win.panel
        property: "width"
        value: holder.width
        when: win.openHere
    }
    Binding {
        target: win.panel
        property: "maxHeight"
        // what's left of the screen below the console's top, minus its frame
        value: win.screenHeight * 0.74 - 2 * Style.consolePad - 60
        when: win.openHere
    }
}
