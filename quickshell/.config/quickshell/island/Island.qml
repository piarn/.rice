// One screen's island: the center of the top row. Collapsed it's just the
// date and time (Clock), floating; grown (the calendar open on this screen)
// it becomes a 600px card that adopts the shared Panel and extends downward
// over the windows below — the Spacer reserves only the collapsed height,
// so nothing reflows. The workspaces and the status readout float in the
// top corners (Card); everything else opens in the console
// (console/ConsoleWindow.qml).
//
// Keyboard focus (sway, as the old popups found it):
//  - collapsed: none at all, so clicking a workspace or the clock never
//    takes the keyboard from the window you're in
//  - grown: on demand (Esc closes); switching back drops focus at once
//  - sway gives no reliable "clicked outside" for layer surfaces, so while
//    grown a transparent catcher covers every screen and a click on it
//    collapses the island (the click itself is swallowed, like rofi). The
//    grown island moves to the overlay layer so the catcher (top layer)
//    stays underneath it.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: island

    required property var modelData
    required property Item panel

    readonly property int islandWidth: 600
    // only the calendar grows the island; everything else is the console
    readonly property bool grownHere: IslandState.islandOpen && IslandState.screen === modelData

    screen: modelData
    anchors.top: true
    margins.top: 6
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: frame.width
    implicitHeight: frame.height
    WlrLayershell.namespace: "quickshell-island"
    // Above the click catcher (top layer) whenever anything is open, so the
    // clock still works instead of just closing what's open.
    WlrLayershell.layer: IslandState.grown ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: !grownHere ? WlrKeyboardFocus.None
        : panel.needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // Quick settings' "keep awake": the island is always mapped, which is
    // what the idle-inhibit protocol needs from the inhibiting surface.
    IdleInhibitor {
        window: island
        enabled: IdleState.inhibit
    }

    Variants {
        model: island.grownHere ? Quickshell.screens : []

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

    // just the clock, floating, until it grows into a card
    Rectangle {
        id: frame
        width: island.grownHere ? island.islandWidth : strip.implicitWidth + 2 * Style.border
        height: strip.height + (island.grownHere ? holder.height + 2 * Style.pad : 0) + 2 * Style.border
        color: island.grownHere ? Colors.mantle : "transparent"
        radius: Style.radius
        border.width: island.grownHere ? Style.border : 0
        border.color: island.panel.needsKeyboard ? Colors.neon : Colors.surface

        Clock {
            id: strip
            screen: island.modelData
            x: Style.border
            y: Style.border
            width: parent.width - 2 * Style.border
        }

        Item {
            id: holder
            x: Style.pad
            y: strip.y + strip.height + Style.pad / 2
            width: parent.width - 2 * Style.pad
            height: island.grownHere ? island.panel.implicitHeight : 0
        }
    }

    // adopt the shared panel while grown here; it goes back to its holder in
    // shell.qml when the Binding lets go
    Binding {
        target: island.panel
        property: "parent"
        value: holder
        when: island.grownHere
    }
    Binding {
        target: island.panel
        property: "width"
        value: holder.width
        when: island.grownHere
    }
    Binding {
        target: island.panel
        property: "maxHeight"
        value: (island.modelData ? island.modelData.height : 1080) * 0.7 - 60
        when: island.grownHere
    }

    onGrownHereChanged: if (grownHere) Qt.callLater(panel.focusCurrent)
}
