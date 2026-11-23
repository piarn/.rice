// One screen's top row, in a single window: the workspaces on the left, the
// date and time in the middle, the status readout on the right, floating on
// the wallpaper. BarState.centered pulls the workspaces and readout in
// beside the clock instead of out to the screen's edges. The window spans the screen's width and reserves the
// strip (40px) so windows start below it; its mask covers only the three
// pieces, so clicks between them reach whatever is underneath.
//
// The clock grows into the calendar (the only thing the island still
// opens): a 600px card that adopts the shared Panel and extends downward
// over the windows — the reserved zone stays 40px, so nothing reflows.
//
// Keyboard focus (sway, as the old popups found it):
//  - normally none at all, so clicking a workspace or the clock never takes
//    the keyboard from the window you're in
//  - calendar open: on demand (Esc closes)
//  - sway gives no reliable "clicked outside" for layer surfaces, so while
//    the calendar is open a transparent catcher covers every screen and a
//    click on it closes it. While anything is open (calendar or console)
//    the row moves to the overlay layer, above the catcher, so it stays
//    clickable.
import Quickshell
import Quickshell.Wayland
import QtQuick
import quickshell
import "../state"
import "../components"

PanelWindow {
    id: row

    required property var modelData
    required property Item panel

    readonly property int strip: 40
    readonly property int calendarWidth: 600
    // centered bar: the pieces sit `pull` away from the (collapsed) clock
    readonly property real centerX: width / 2
    readonly property real clockHalf: (clock.implicitWidth + 2 * Style.border) / 2
    readonly property int pull: 24
    readonly property bool grownHere: IslandState.islandOpen && IslandState.screen === modelData

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Math.max(strip, frame.y + frame.height + 4)
    exclusiveZone: strip
    color: "transparent"
    mask: Region {
        item: workspaces
        Region { item: frame }
        Region { item: readout }
    }
    WlrLayershell.namespace: "quickshell-toprow"
    WlrLayershell.layer: IslandState.grown ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: !grownHere ? WlrKeyboardFocus.None
        : panel.needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // Quick settings' "keep awake": the row is always mapped, which is what
    // the idle-inhibit protocol needs from the inhibiting surface.
    IdleInhibitor {
        window: row
        enabled: IdleState.inhibit
    }

    Variants {
        model: row.grownHere ? Quickshell.screens : []

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

    Workspaces {
        id: workspaces
        x: BarState.centered ? row.centerX - row.clockHalf - row.pull - width : 8
        y: 6
        height: Style.barHeight
    }

    StatusReadout {
        id: readout
        screen: row.modelData
        x: BarState.centered ? row.centerX + row.clockHalf + row.pull : parent.width - width - 8
        y: 6
        height: Style.barHeight
    }

    // just the clock, floating, until it grows into the calendar
    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        width: row.grownHere ? row.calendarWidth : clock.implicitWidth + 2 * Style.border
        height: clock.height + (row.grownHere ? holder.height + 2 * Style.pad : 0) + 2 * Style.border
        color: row.grownHere ? Colors.mantle : "transparent"
        radius: Style.radius
        border.width: row.grownHere ? Style.border : 0
        border.color: Colors.surface
        clip: true
        Behavior on height {
            enabled: row.grownHere
            NumberAnimation { duration: Style.medium; easing.type: Easing.OutCubic }
        }

        Clock {
            id: clock
            screen: row.modelData
            x: Style.border
            y: Style.border
            width: parent.width - 2 * Style.border
        }

        Item {
            id: holder
            x: Style.pad
            y: clock.y + clock.height + Style.pad / 2
            width: parent.width - 2 * Style.pad
            height: row.grownHere ? row.panel.implicitHeight : 0
        }
    }

    // adopt the shared panel while open here; it goes back to its holder in
    // shell.qml when the Binding lets go
    Binding {
        target: row.panel
        property: "parent"
        value: holder
        when: row.grownHere
    }
    Binding {
        target: row.panel
        property: "width"
        value: holder.width
        when: row.grownHere
    }
    Binding {
        target: row.panel
        property: "maxHeight"
        value: (row.modelData ? row.modelData.height : 1080) * 0.7 - 60
        when: row.grownHere
    }

    onGrownHereChanged: if (grownHere) Qt.callLater(panel.focusCurrent)
}
