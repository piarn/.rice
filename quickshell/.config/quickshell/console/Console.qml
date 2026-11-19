// The console: the one surface in the middle of the screen ($mod+d). A row
// of page names — run, quick, sound, network, bluetooth, notifications,
// clipboard — then the open page, scrolling past the screen's cap. Created
// once (shell.qml); whichever screen's ConsoleWindow is open adopts it.
//
// Pages are built the first time they open and kept after that, so opening
// the console costs only the page you look at. run and clipboard are built
// up front: they own IPC handlers (commandcenter, clipboard).
//
// Keys:
//   1–7, Tab / Shift+Tab   change page (Alt+1–7 or Ctrl+Tab from a text box)
//   the page's own keys    j/k, Space, Enter, h/l, letters (island/Tab.qml)
//   ?                      the page's keys
//   any other letter       jumps to run and types it: search from any page
//   Esc                    drops the selection or the key list, then closes
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
    property bool showKeys: false

    readonly property var pages: [runPage, quickLoader.item, soundLoader.item, networkLoader.item,
                                  bluetoothLoader.item, notificationsLoader.item, clipboardPage].filter(p => p)
    readonly property Item current: pages.find(p => p.shown) || null
    // a text box most of the time, and page keys the rest: always the keyboard
    readonly property bool needsKeyboard: true

    implicitHeight: header.height + 18 + flick.height

    function focusCurrent() {
        if (current && current.initialFocus) current.initialFocus.forceActiveFocus()
        else keys.forceActiveFocus()
    }

    function openIndex(i) {
        if (i >= 0 && i < Routes.CONSOLE_TABS.length) IslandState.open(Routes.CONSOLE_TABS[i], IslandState.screen)
    }

    // the global keys, after the page's own in the ? list
    readonly property var globalKeys: [["1–7  tab", "change page"], ["j  k", "move"], ["space", "toggle"],
                                       ["enter", "open"], ["h  l", "adjust a level"], ["a–z", "search"], ["esc", "back, close"]]

    Connections {
        target: IslandState
        function onTabChanged() {
            if (!IslandState.consoleOpen) return
            root.showKeys = false
            flick.contentY = 0
            // the new page fades in; the old one is already gone
            pageFade.restart()
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
            if (event.text === "?") { root.showKeys = !root.showKeys; event.accepted = true; return }
            if (root.showKeys && k === Qt.Key_Escape) { root.showKeys = false; event.accepted = true; return }
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

    // the page names: the open one white, the rest grey
    Row {
        id: header
        x: Style.inset
        height: 22
        spacing: 18

        Repeater {
            model: Routes.CONSOLE_TABS

            delegate: MonoText {
                id: pageName
                required property string modelData
                readonly property bool open: IslandState.tab === modelData
                readonly property int unread: modelData === "notifications" ? NotificationState.notifications.length : 0
                anchors.verticalCenter: parent.verticalCenter
                color: open || pageMouse.containsMouse ? Colors.fg : Colors.gray
                Behavior on color { ColorAnimation { duration: Style.fast } }
                text: modelData + (unread ? " " + unread : "")

                MouseArea {
                    id: pageMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: IslandState.open(pageName.modelData, IslandState.screen)
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.topMargin: 18
        width: parent.width
        height: Math.min(root.showKeys ? keyList.implicitHeight : content.implicitHeight, root.maxHeight)
        contentHeight: root.showKeys ? keyList.implicitHeight : content.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: content
            visible: !root.showKeys
            width: flick.width - (flick.interactive ? 8 : 0)
            implicitHeight: root.current ? root.current.implicitHeight : 0

            NumberAnimation {
                id: pageFade
                target: content
                property: "opacity"
                from: 0
                to: 1
                duration: 90
                easing.type: Easing.OutQuad
            }

            RunTab { id: runPage; width: parent.width }
            ClipboardTab { id: clipboardPage; width: parent.width }

            // built on first open, kept after
            component LazyPage: Loader {
                id: lazy
                property string page: ""
                width: parent.width
                // a latch, not a binding: once on, it stays on
                active: false
                function check() { if (!active && IslandState.tab === page) active = true }
                Component.onCompleted: check()
                property Connections watch: Connections {
                    target: IslandState
                    function onTabChanged() { lazy.check() }
                }
            }
            LazyPage { id: quickLoader; page: "quick"; sourceComponent: Component { QuickTab {} } }
            LazyPage { id: soundLoader; page: "sound"; sourceComponent: Component { SoundTab {} } }
            LazyPage { id: networkLoader; page: "network"; sourceComponent: Component { NetworkTab {} } }
            LazyPage { id: bluetoothLoader; page: "bluetooth"; sourceComponent: Component { BluetoothTab {} } }
            LazyPage { id: notificationsLoader; page: "notifications"; sourceComponent: Component { NotificationsTab {} } }
        }

        // ?: the page's keys, then the console's
        Column {
            id: keyList
            visible: root.showKeys
            width: flick.width

            Repeater {
                model: root.showKeys ? (root.current ? root.current.keyList() : []).concat(root.globalKeys) : []

                delegate: Item {
                    required property var modelData
                    width: keyList.width
                    height: Style.rowHeight

                    MonoText {
                        x: Style.inset
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        color: Colors.fg
                        text: modelData[0]
                    }
                    MonoText {
                        x: Style.inset + 100
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.gray2
                        text: modelData[1]
                    }
                }
            }
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
