// The console's run page, the command center ($mod+d / $mod+Space): a
// search box and a short list. Empty, it's the home screen — a live status
// line, a row of quick toggles (←/→ pick, Enter flips), then apps,
// most-used first. Typing searches apps, and folds in settings (`wifi`,
// `vol`, `codec` …), projects, tools, session actions and windows; prefix
// modes narrow it (=calc >run /files ?web @windows ~dev !tools :session
// ,settings). ←/→ step a level row. Rows and the mode-dispatch logic live
// in run/RunSection.qml, run/ResultRow.qml; DevSection/ToolsSection/
// SettingsSection feed it.
//
// IPC: `qs ipc call commandcenter toggle`, or `commandcenter open '@'` to
// open it pre-typed (e.g. a bind straight to the window switcher).
import Quickshell
import Quickshell.Io
import QtQuick
import quickshell
import "../../components"
import "../../state"
import "../../island"
import "run"

Tab {
    id: cc
    name: "run"
    initialFocus: input
    spacing: 8

    readonly property int maxRows: 8

    DevSection { id: dev }
    ToolsSection { id: tools; onOpenPopup: (name) => cc.popup(name) }
    SettingsSection { id: settings; active: cc.shown; onOpenPage: (page) => cc.popup(page) }
    RunSection {
        id: run
        query: input.text
        active: cc.shown
        devRows: dev.rows
        toolRows: tools.rows
        settingsRows: settings.rows
        homeRows: [settings.statusRow, settings.chipsRow]
        onOpenPopup: (name) => cc.popup(name)
    }

    property int selected: 0
    property int armed: -1        // confirm row waiting for its second Enter
    property int chip: 0          // the picked toggle on a chips row
    readonly property var results: run.results

    // headers and the status line are never selected
    function selectable(i) {
        const it = results[i]
        return it && it.kind !== "header" && it.kind !== "status"
    }
    // where selection starts: the first real result, so Enter right away
    // never flips a home-screen toggle (↑ still reaches the chips)
    function firstSelectable() {
        for (let i = 0; i < results.length; i++) if (selectable(i) && results[i].kind !== "chips") return i
        for (let i = 0; i < results.length; i++) if (selectable(i)) return i
        return 0
    }
    onResultsChanged: {
        selected = Math.min(selected, Math.max(results.length - 1, 0))
        if (!selectable(selected)) selected = firstSelectable()
    }

    function move(delta) {
        armed = -1
        if (!results.length) return
        let i = selected
        do { i += delta > 0 ? 1 : -1 } while (i >= 0 && i < results.length && !selectable(i) )
        if (Math.abs(delta) > 1) i = Math.max(0, Math.min(results.length - 1, selected + delta))
        if (i >= 0 && i < results.length && selectable(i)) selected = i
    }

    // ←/→ on a level steps it, on a chips row picks a chip; true = handled
    function sideways(delta) {
        const it = results[selected]
        if (!it) return false
        if (it.kind === "level" && it.adjust) { it.adjust(delta * 0.05); return true }
        if (it.kind === "chips") { chip = Math.max(0, Math.min(it.chips.length - 1, chip + delta)); return true }
        return false
    }

    function popup(name) {
        IslandState.open(name, cc.screen)
    }

    function activate(item, alt) {
        if (!item) return
        if (item.kind === "chips") {
            const c = item.chips[chip]
            if (c && c.run) c.run()
            return
        }
        if (item.kind === "toggle" || item.kind === "choice" || item.kind === "level") {
            if (item.run) item.run()
            return
        }
        if (item.confirm && armed !== selected) {
            armed = selected
            return
        }
        armed = -1
        if (item.key) LauncherUsage.record(item.key)
        if (!item.keepOpen) cc.close()
        item.run(alt)
    }

    onOpened: {
        // the codec settings need the cards, read once (quick and sound refresh them)
        if (!VolumeState.cards.length) VolumeState.refreshExtras()
        input.text = IslandState.runPrefix
        IslandState.runPrefix = ""
        selected = firstSelectable()
        armed = -1
        chip = 0
        dev.refresh()
    }

    IpcHandler {
        target: "commandcenter"
        function toggle(): void { IslandState.toggle("run") }
        function close(): void { if (cc.shown) cc.close() }
        function open(text: string): void { IslandState.openRun(text) }
    }

    Rectangle {
        width: parent.width
        height: 34
        radius: Style.round
        color: Style.tint(Colors.fg, 0.05)
        border.width: 0

        MonoText {
            id: prompt
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.neon
            text: "›"
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: modeLabel.visible ? modeLabel.width + 20 : 10
            verticalAlignment: TextInput.AlignVCenter
            color: Colors.fg
            font.family: Style.font
            font.pixelSize: Style.fontSize
            renderType: Text.NativeRendering
            clip: true
            onTextChanged: { cc.selected = cc.firstSelectable(); cc.armed = -1; cc.chip = 0 }

            Keys.onPressed: (event) => {
                const ctrl = event.modifiers & Qt.ControlModifier
                const shift = event.modifiers & Qt.ShiftModifier
                if (event.key === Qt.Key_Escape) cc.close()
                else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right)
                         && cc.sideways(event.key === Qt.Key_Right ? 1 : -1)) {}
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
            visible: run.mode !== "apps"
            color: Colors.gray
            text: run.mode
        }
    }

    ListView {
        id: list
        width: parent.width
        height: Math.min(count, cc.maxRows) * 34
        visible: count > 0
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
            chip: cc.chip
            tag: modelData.group || ""
            onClicked: (alt) => cc.activate(modelData, alt)
        }
    }

    MonoText {
        width: parent.width
        elide: Text.ElideRight
        leftPadding: Style.inset
        color: Colors.gray
        text: run.hint
    }
}
