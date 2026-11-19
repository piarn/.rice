// Base for every page (the console's, the calendar's): a Column shown while
// it's the open tab. Keeps the names the old popups used (innerWidth,
// screen, opened(), close(), openPopup()).
//
// Keys while the page itself has focus (no text field), console-style:
//   j/k or ↓/↑   move between the page's readout rows (anything with
//                `consoleRow: true` — ReadoutRow, LevelRow — in order)
//   Space        toggle the selected row; Enter opens what it opens
//   h/l or ←/→   step the selected row (sliders)
//   letters      the page's `hotkeys` ({"w": () => ..., ...}), shown on
//                the rows as dim key hints
//   Esc          drops the selection first
// A page with its own list (run, notifications, clipboard) overrides
// handleKey instead.
import QtQuick
import "../state"

Column {
    id: tab

    required property string name
    readonly property bool shown: IslandState.tab === name
    readonly property var screen: IslandState.screen
    readonly property int innerWidth: width
    // on top of run/clipboard, which always want it: e.g. a password field
    property bool needsKeyboard: false
    // what gets keyboard focus when the tab opens (null: the console itself)
    property Item initialFocus: null

    // keyboard: the selected row, and the page's letters
    property var selectedRow: null
    property var hotkeys: ({})

    signal opened()

    // the page's readout rows, top to bottom, visible ones only
    function rows() {
        const out = []
        const walk = (item) => {
            for (const child of item.children) {
                if (!child.visible) continue
                if (child.consoleRow === true) out.push(child)
                else walk(child)
            }
        }
        walk(tab)
        return out
    }

    // [key, label] for the console's `?` list: every row with a key
    function keyList() {
        return rows().filter(r => r.key).map(r => [r.key, r.label])
    }

    function moveSelection(delta) {
        const list = rows()
        if (!list.length) return
        const i = list.indexOf(selectedRow)
        selectedRow = i < 0 ? list[delta > 0 ? 0 : list.length - 1]
            : list[Math.max(0, Math.min(list.length - 1, i + delta))]
    }

    // true = handled
    function handleKey(event) {
        const k = event.key
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return false
        if (k === Qt.Key_J || k === Qt.Key_Down) { moveSelection(1); return true }
        if (k === Qt.Key_K || k === Qt.Key_Up) { moveSelection(-1); return true }
        if (selectedRow && k === Qt.Key_Space) {
            selectedRow.activate()
            return true
        }
        // Enter opens what a row opens (and toggles one that opens nothing)
        if (selectedRow && (k === Qt.Key_Return || k === Qt.Key_Enter)) {
            if (selectedRow.secondary) selectedRow.secondary()
            else selectedRow.activate()
            return true
        }
        if (selectedRow && (k === Qt.Key_H || k === Qt.Key_Left)) { selectedRow.adjust(-1); return true }
        if (selectedRow && (k === Qt.Key_L || k === Qt.Key_Right)) { selectedRow.adjust(1); return true }
        if (k === Qt.Key_Escape && selectedRow) { selectedRow = null; return true }
        const fn = hotkeys[event.text]
        if (fn) { fn(); return true }
        return false
    }

    function close() { IslandState.close() }
    function openPopup(name) { IslandState.open(name, screen) }
    // keyboard focus back to the console itself, e.g. when a form closes
    function focusCatcher() { IslandState.panelFocusRequested() }

    visible: shown
    spacing: 4
    onShownChanged: if (!shown) selectedRow = null; else opened()
    // a page built lazily (console/Console.qml) is created already shown
    Component.onCompleted: if (shown) opened()
}
