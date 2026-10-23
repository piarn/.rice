// The launcher ($mod+d / $mod+Space): a search box and a short list — apps,
// most-used first, and the prefix modes (=calc >run /files ?web @windows
// ~dev !tools :session). Rows and the mode dispatch live in RunSection.qml
// and ResultRow.qml; DevSection/ToolsSection feed RunSection's ~/! modes.
//
// One window, on the focused screen while open: a box near the top, and a
// transparent rest of the screen that closes it when clicked (sway gives no
// reliable "clicked outside" for layer surfaces).
//
// IPC: `qs ipc call commandcenter toggle`, or `commandcenter open ':'` to
// open it pre-typed (e.g. a bind straight to the session actions).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import quickshell
import "../components"
import "../state"

Scope {
    id: cc

    property bool shown: false
    // a row waiting for typed input (a wi-fi password): {prompt, submit(text)}
    property var prompt: null
    readonly property int maxRows: 8

    property int selected: 0
    property int armed: -1        // confirm row waiting for its second Enter
    readonly property var results: run.results
    onResultsChanged: selected = Math.min(selected, Math.max(results.length - 1, 0))

    function open(text) {
        win.screen = ScreenState.focused
        prompt = null
        input.text = text || ""
        selected = 0
        armed = -1
        dev.refresh()
        shown = true
        Qt.callLater(() => input.forceActiveFocus())
    }
    function close() { shown = false; prompt = null }

    // Enter on a prompt: hand the text over, back to the mode it came from
    // (where the status row shows how it went). Esc: just back.
    function submitPrompt() {
        const item = prompt
        prompt = null
        const text = input.text
        input.text = "#"
        item.submit(text)
    }
    function cancelPrompt() {
        prompt = null
        input.text = "#"
    }
    function toggle() { if (shown) close(); else open("") }

    function move(delta) {
        armed = -1
        if (results.length) selected = Math.max(0, Math.min(results.length - 1, selected + delta))
    }

    function activate(item, alt) {
        if (!item) return
        if (item.prompt && !alt) {
            prompt = item
            input.text = ""
            return
        }
        if (item.kind === "toggle" || item.kind === "choice" || item.kind === "level") {
            if (item.run) item.run(alt)
            return
        }
        if (item.confirm && armed !== selected) {
            armed = selected
            return
        }
        armed = -1
        if (item.key) LauncherUsage.record(item.key)
        if (!item.keepOpen) close()
        item.run(alt)
    }

    IpcHandler {
        target: "commandcenter"
        function toggle(): void { cc.toggle() }
        function close(): void { cc.close() }
        function open(text: string): void { cc.open(text) }
    }

    DevSection { id: dev }
    ToolsSection { id: tools }
    RunSection {
        id: run
        // a password being typed never reaches the search
        query: cc.prompt ? "#" : input.text
        active: cc.shown
        devRows: dev.rows
        toolRows: tools.rows
    }

    PanelWindow {
        id: win
        visible: cc.shown
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: cc.close()
        }

        Rectangle {
            id: box
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.18
            width: 640
            height: column.implicitHeight + 2 * Style.pad
            color: Colors.black
            border.width: Style.border
            border.color: Colors.dim

            // clicks inside don't reach the close-on-click area behind
            MouseArea { anchors.fill: parent }

            Column {
                id: column
                x: Style.pad
                y: Style.pad
                width: parent.width - 2 * Style.pad
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 34
                    color: Colors.black
                    border.width: Style.border
                    border.color: Colors.dim

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: modeLabel.visible ? modeLabel.width + 20 : 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colors.fg
                        echoMode: cc.prompt ? TextInput.Password : TextInput.Normal
                        font.family: "monospace"
                        font.pixelSize: 14
                        clip: true
                        onTextChanged: if (!cc.prompt) { cc.selected = 0; cc.armed = -1 }

                        Keys.onPressed: (event) => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            const shift = event.modifiers & Qt.ShiftModifier
                            if (cc.prompt) {
                                if (event.key === Qt.Key_Escape) cc.cancelPrompt()
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) cc.submitPrompt()
                                else return
                            }
                            else if (event.key === Qt.Key_Escape) cc.close()
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) cc.activate(cc.results[cc.selected], shift)
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) cc.move(1)
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) cc.move(-1)
                            else if (event.key === Qt.Key_PageDown) cc.move(cc.maxRows)
                            else if (event.key === Qt.Key_PageUp) cc.move(-cc.maxRows)
                            else return
                            event.accepted = true
                        }
                    }

                    MonoText {
                        id: modeLabel
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cc.prompt || run.mode !== "apps"
                        color: Colors.gray2
                        text: cc.prompt ? "password" : run.mode
                    }
                }

                ListView {
                    width: parent.width
                    height: Math.min(count, cc.maxRows) * 34
                    visible: count > 0 && !cc.prompt
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: cc.results
                    currentIndex: cc.selected
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: ResultRow {
                        required property var modelData
                        required property int index
                        item: modelData
                        current: index === cc.selected
                        armed: index === cc.armed
                        tag: modelData.group || ""
                        onClicked: (alt) => cc.activate(modelData, alt)
                    }
                }

                MonoText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Colors.gray
                    text: cc.prompt ? cc.prompt.prompt + " · enter connects · esc back"
                        : run.hint + " · ↑↓/^j^k move · esc close"
                }
            }
        }
    }
}
