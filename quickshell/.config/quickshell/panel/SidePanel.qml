// The control panel's contents: a row of named tabs, then the open tab,
// scrolling when it's taller than the screen. Created once (shell.qml) so
// every tab — its state, its IPC handler — exists once; whichever screen's
// SideWindow is open adopts it.
//
// Keys: h/l or ←/→ switch tabs while the panel itself has focus (not in a
// text field), Ctrl+Tab / Ctrl+Shift+Tab anywhere, Esc closes.
import QtQuick
import quickshell
import "../state"
import "../components"
import "tabs"
import "../island/routes.js" as Routes

FocusScope {
    id: panel

    readonly property var tabs: [quickTab, soundTab, networkTab, bluetoothTab, notificationsTab]
    // what the open tab needs; the SideWindow caps it at the screen's height
    implicitHeight: header.height + 21 + content.implicitHeight
    readonly property Item current: tabs.find(t => t.shown) || null
    // a tab that's in a text field right now (wi-fi password, search)
    readonly property bool needsKeyboard: current !== null && current.needsKeyboard

    function focusCurrent() {
        if (current && current.initialFocus) current.initialFocus.forceActiveFocus()
        else keys.forceActiveFocus()
    }

    Connections {
        target: IslandState
        function onTabChanged() { if (IslandState.panelOpen) Qt.callLater(panel.focusCurrent) }
        function onPanelFocusRequested() { if (IslandState.panelOpen) keys.forceActiveFocus() }
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
        enabled: IslandState.panelOpen
        onActivated: IslandState.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
        enabled: IslandState.panelOpen
        onActivated: IslandState.step(-1)
    }

    // tab row: names, the open one filled like the focused workspace
    Item {
        id: header
        width: parent.width
        height: 30

        // tab names as plain words; the open one bright with the accent
        // underline, like the focused workspace
        Row {
            id: tabRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: Routes.PANEL_TABS

                delegate: Rectangle {
                    id: tabButton
                    required property string modelData
                    readonly property bool open: IslandState.tab === modelData
                    readonly property int unread: modelData === "notifications" ? NotificationState.notifications.length : 0
                    width: tabLabel.implicitWidth + 16
                    height: 28
                    radius: Style.round
                    color: tabMouse.containsMouse && !open ? Style.tint(Colors.fg, 0.06) : "transparent"

                    MonoText {
                        id: tabLabel
                        anchors.centerIn: parent
                        color: tabButton.open || tabMouse.containsMouse ? Colors.fg : Colors.gray
                        text: (tabButton.modelData === "notifications" ? "notifs" : tabButton.modelData)
                            + (tabButton.unread ? " " + tabButton.unread : "")
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: tabButton.open ? tabLabel.implicitWidth : 0
                        height: 2
                        color: Colors.neon
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandState.open(tabButton.modelData, IslandState.screen)
                    }
                }
            }
        }

        Icon {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 16
            color: closeMouse.containsMouse ? Colors.fg : Colors.gray2
            text: "\u{e5cd}"   // close

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: IslandState.close()
            }
        }
    }

    Rectangle {
        id: rule
        anchors.top: header.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 1
        color: Colors.surface
    }

    // the open tab, scrolling past the screen's height
    Flickable {
        id: flick
        anchors.top: rule.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: content.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: content
            width: flick.width - (flick.interactive ? 8 : 0)
            implicitHeight: panel.current ? panel.current.implicitHeight : 0

            QuickTab { id: quickTab; width: parent.width }
            SoundTab { id: soundTab; width: parent.width }
            NetworkTab { id: networkTab; width: parent.width }
            BluetoothTab { id: bluetoothTab; width: parent.width }
            NotificationsTab { id: notificationsTab; width: parent.width }
        }

        Rectangle {
            visible: flick.interactive
            parent: flick
            x: flick.width - width
            y: flick.visibleArea.yPosition * flick.height
            width: 3
            height: flick.visibleArea.heightRatio * flick.height
            color: Colors.dim
        }
    }

    // a new tab starts at the top
    Connections {
        target: IslandState
        function onTabChanged() { flick.contentY = 0 }
    }
}
