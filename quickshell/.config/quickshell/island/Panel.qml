// The grown island's contents: the calendar, dropping from the clock (every
// other page lives in the console, console/Console.qml). Created once
// (shell.qml); whichever screen's Island is grown adopts it
// (island/Island.qml). Esc closes it.
import QtQuick
import quickshell
import "../state"
import "../components"
import "tabs"

FocusScope {
    id: panel

    implicitHeight: calendarTab.implicitHeight
    // the cap, set by the Island adopting this (70% of its screen)
    property real maxHeight: 700

    readonly property Item current: calendarTab.shown ? calendarTab : null
    readonly property bool needsKeyboard: current !== null && current.needsKeyboard

    function focusCurrent() { keys.forceActiveFocus() }

    Connections {
        target: IslandState
        function onTabChanged() { if (IslandState.islandOpen) Qt.callLater(panel.focusCurrent) }
        function onPanelFocusRequested() { if (IslandState.islandOpen) keys.forceActiveFocus() }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: (event) => {
            if (panel.current && panel.current.handleKey(event)) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Escape) {
                IslandState.close()
                event.accepted = true
            }
        }
    }

    CalendarTab { id: calendarTab; width: parent.width }
}
