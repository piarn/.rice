// One screen's control panel: a full-height card on the right edge that
// slides in when a settings tab opens there (quick, sound, network,
// bluetooth, notifications; island/routes.js). It adopts the shared
// SidePanel the way the island adopts its Panel, so every tab exists once.
//
// Like the grown island: on the overlay layer, keyboard on demand (or
// exclusive while a tab types, e.g. a wi-fi password), and a transparent
// catcher over every screen closes it on a click outside — the island
// stays above that catcher, so its icons switch tabs instead.
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

    readonly property bool openHere: IslandState.panelOpen && IslandState.screen === modelData
    readonly property int panelWidth: 460

    screen: modelData
    visible: openHere
    // just under the status icons' card (island/Card.qml: 6 + 30), as tall
    // as the open tab, down to the screen's bottom edge (then it scrolls)
    readonly property int topGap: 6 + Style.barHeight + 6
    anchors { top: true; right: true }
    margins { top: topGap; right: 6 }
    implicitWidth: panelWidth
    implicitHeight: Math.min(panel.implicitHeight + 2 * Style.pad, (modelData ? modelData.height : 1080) - topGap - 6)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !openHere ? WlrKeyboardFocus.None
        : panel.needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

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

    // slides in from the right edge on opening
    property real slide: 0
    onOpenHereChanged: {
        if (openHere) {
            slide = 1
            slideIn.restart()
            Qt.callLater(panel.focusCurrent)
        }
    }
    NumberAnimation {
        id: slideIn
        target: win
        property: "slide"
        to: 0
        duration: 140
        easing.type: Easing.OutCubic
    }

    Rectangle {
        id: frame
        x: win.slide * (win.width + 8)
        width: win.width
        height: win.height
        color: Colors.mantle
        radius: Style.radius
        border.width: Style.border
        border.color: win.panel.needsKeyboard ? Colors.neon : Colors.surface

        Item {
            id: holder
            anchors.fill: parent
            anchors.margins: Style.pad
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
        property: "height"
        value: holder.height
        when: win.openHere
    }
}
