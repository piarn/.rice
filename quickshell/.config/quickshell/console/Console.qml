// The console: the one surface in the middle of the screen ($mod+d). A row
// of pages — run, quick, sound, net, bt, notifs, clip — then the open page,
// scrolling past the screen's cap. Created once (shell.qml) so every page,
// its state and its IPC handler exist once; whichever screen's
// ConsoleWindow is open adopts it.
//
// Keys:
//   1–7, Tab / Shift+Tab   change page (Alt+1–7 or Ctrl+Tab from a text box)
//   the page's own keys    j/k, Space, h/l, letters (island/Tab.qml)
//   any other letter       jumps to run and types it: search from any page
//   Esc                    drops the selection, then closes
import QtQuick
import quickshell
import "../state"
import "../components"
import "pages"
import "../island/routes.js" as Routes

FocusScope {
    id: root

    // the page area's cap, set by the ConsoleWindow adopting this
    property real maxHeight: 700

    readonly property var pages: [runPage, quickPage, soundPage, networkPage, bluetoothPage, notificationsPage, clipboardPage]
    readonly property Item current: pages.find(p => p.shown) || null
    // a text box most of the time, and page keys the rest: always the keyboard
    readonly property bool needsKeyboard: true

    implicitHeight: header.height + 21 + flick.height

    function focusCurrent() {
        if (current && current.initialFocus) current.initialFocus.forceActiveFocus()
        else keys.forceActiveFocus()
    }

    function openIndex(i) {
        if (i >= 0 && i < Routes.CONSOLE_TABS.length) IslandState.open(Routes.CONSOLE_TABS[i], IslandState.screen)
    }

    Connections {
        target: IslandState
        function onTabChanged() {
            if (!IslandState.consoleOpen) return
            flick.contentY = 0
            Qt.callLater(root.focusCurrent)
        }
        function onPanelFocusRequested() { if (IslandState.consoleOpen) keys.forceActiveFocus() }
    }

    // keep the selected row in view
    Connections {
        target: root.current
        ignoreUnknownSignals: true
        function onSelectedRowChanged() {
            const row = root.current ? root.current.selectedRow : null
            if (!row) return
            const p = row.mapToItem(content, 0, 0)
            if (p.y < flick.contentY) flick.contentY = p.y
            else if (p.y + row.height > flick.contentY + flick.height)
                flick.contentY = Math.min(flick.contentHeight - flick.height, p.y + row.height - flick.height)
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: (event) => {
            const k = event.key
            const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier)
            if (root.current && root.current.handleKey(event)) {
                event.accepted = true
                return
            }
            if (!mods && k >= Qt.Key_1 && k <= Qt.Key_7) root.openIndex(k - Qt.Key_1)
            else if (k === Qt.Key_Tab) IslandState.step(1)
            else if (k === Qt.Key_Backtab) IslandState.step(-1)
            else if (k === Qt.Key_Escape) IslandState.close()
            // anything printable starts a search
            else if (!mods && event.text.length === 1 && event.text > " ") IslandState.openRun(event.text)
            else return
            event.accepted = true
        }
    }

    Shortcut {
        sequences: ["Ctrl+Tab"]
        enabled: IslandState.consoleOpen
        onActivated: IslandState.step(1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]
        enabled: IslandState.consoleOpen
        onActivated: IslandState.step(-1)
    }
    Instantiator {
        model: Routes.CONSOLE_TABS.length
        delegate: Shortcut {
            required property int index
            sequence: "Alt+" + (index + 1)
            enabled: IslandState.consoleOpen
            onActivated: root.openIndex(index)
        }
    }

    // the page row: a faint number and the name; the open one bright with
    // the accent underline
    Item {
        id: header
        width: parent.width
        height: 24

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Repeater {
                model: Routes.CONSOLE_TABS

                delegate: Item {
                    id: pageButton
                    required property string modelData
                    required property int index
                    readonly property bool open: IslandState.tab === modelData
                    readonly property int unread: modelData === "notifications" ? NotificationState.notifications.length : 0
                    width: pageRow.implicitWidth
                    height: 24

                    Row {
                        id: pageRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        MonoText {
                            color: Colors.dim
                            text: String(pageButton.index + 1)
                        }
                        MonoText {
                            id: pageName
                            color: pageButton.open || pageMouse.containsMouse ? Colors.fg
                                : pageButton.unread ? Colors.gray2 : Colors.gray
                            text: Routes.LABELS[pageButton.modelData] + (pageButton.unread ? " " + pageButton.unread : "")
                        }
                    }

                    Rectangle {
                        anchors.left: pageRow.left
                        anchors.right: pageRow.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: Colors.neon
                        visible: pageButton.open
                    }

                    MouseArea {
                        id: pageMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandState.open(pageButton.modelData, IslandState.screen)
                    }
                }
            }
        }

        MonoText {
            anchors.right: parent.right
            anchors.rightMargin: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            color: escMouse.containsMouse ? Colors.fg : Colors.dim
            text: "esc"

            MouseArea {
                id: escMouse
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

    Flickable {
        id: flick
        anchors.top: rule.bottom
        anchors.topMargin: 10
        width: parent.width
        height: Math.min(content.implicitHeight, root.maxHeight)
        contentHeight: content.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: content
            width: flick.width - (flick.interactive ? 8 : 0)
            implicitHeight: root.current ? root.current.implicitHeight : 0

            RunTab { id: runPage; width: parent.width }
            QuickTab { id: quickPage; width: parent.width }
            SoundTab { id: soundPage; width: parent.width }
            NetworkTab { id: networkPage; width: parent.width }
            BluetoothTab { id: bluetoothPage; width: parent.width }
            NotificationsTab { id: notificationsPage; width: parent.width }
            ClipboardTab { id: clipboardPage; width: parent.width }
        }

        Rectangle {
            visible: flick.interactive
            parent: flick
            x: flick.width - width
            y: flick.visibleArea.yPosition * flick.height
            width: 2
            height: flick.visibleArea.heightRatio * flick.height
            color: Colors.surface
        }
    }
}
