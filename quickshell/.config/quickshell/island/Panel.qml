// The grown island's contents: the tab row, then the open tab (calendar,
// clipboard; the settings are in panel/SidePanel.qml, the run box in
// launcher/Launcher.qml). Created once
// (shell.qml) so every tab — its state, its IPC handler — exists once;
// whichever screen's Island is grown adopts it (island/Island.qml).
//
// Keys: h/l or ←/→ switch tabs while the island itself has focus (not in a
// text field), Ctrl+Tab / Ctrl+Shift+Tab anywhere (plain Tab moves the run
// list), Esc collapses.
import QtQuick
import quickshell
import "../state"
import "../components"
import "tabs"
import "routes.js" as Routes

FocusScope {
    id: panel

    implicitHeight: col.implicitHeight
    // the tab area's cap, set by the Island adopting this (70% of its screen)
    property real maxHeight: 700

    readonly property var tabs: [calendarTab, clipboardTab]
    readonly property Item current: tabs.find(t => t.shown) || null
    // clipboard, or a tab that's in a text field right now
    readonly property bool needsKeyboard: (IslandState.islandOpen && IslandState.wantsKeyboard) || (current !== null && current.needsKeyboard)

    function focusCurrent() {
        if (current && current.initialFocus) current.initialFocus.forceActiveFocus()
        else keys.forceActiveFocus()
    }

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
            if (event.key === Qt.Key_H || event.key === Qt.Key_Left) IslandState.step(-1)
            else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) IslandState.step(1)
            else if (event.key === Qt.Key_Escape) IslandState.close()
            else return
            event.accepted = true
        }
    }

    Shortcut {
        sequences: ["Ctrl+Tab"]
        enabled: IslandState.islandOpen
        onActivated: IslandState.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
        enabled: IslandState.islandOpen
        onActivated: IslandState.step(-1)
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // one square per tab, the open one filled like the focused
        // workspace in the strip; the name (of the hovered tab, else the
        // open one) beside them
        Item {
            width: parent.width
            height: 24

            Row {
                id: tabRow
                // the icons alone are centered, so they never shift as the name
                // beside them changes length
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                property string hovered: ""

                Repeater {
                    model: Routes.ISLAND_TABS

                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool open: IslandState.tab === modelData
                        readonly property var glyphs: ({
                            calendar: "\u{ebcc}",        // calendar_month
                            clipboard: "\u{e14f}"        // content_paste
                        })
                        width: 28
                        height: 28
                        radius: Style.round
                        color: tabMouse.containsMouse && !open ? Style.tint(Colors.fg, 0.06) : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            font.pixelSize: 16
                            color: parent.open || tabMouse.containsMouse ? Colors.fg : Colors.gray
                            text: parent.glyphs[modelData]
                        }

                        // the open one: the accent underline
                        Rectangle {
                            visible: parent.open
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 12
                            height: 2
                            color: Colors.neon
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: tabRow.hovered = containsMouse ? modelData : (tabRow.hovered === modelData ? "" : tabRow.hovered)
                            onClicked: IslandState.open(modelData, IslandState.screen)
                        }
                    }
                }

            }

            MonoText {
                anchors.left: tabRow.right
                anchors.verticalCenter: tabRow.verticalCenter
                leftPadding: 10
                color: tabRow.hovered ? Colors.fg : Colors.gray2
                text: tabRow.hovered || IslandState.tab
            }
        }

        Divider {}

        // the open tab, scrolling past maxHeight
        Flickable {
            width: parent.width
            height: Math.min(content.implicitHeight, panel.maxHeight)
            contentHeight: content.implicitHeight
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: content
                width: parent.width
                implicitHeight: panel.current ? panel.current.implicitHeight : 0

                CalendarTab { id: calendarTab; width: parent.width }
                ClipboardTab { id: clipboardTab; width: parent.width }
            }
        }
    }
}
