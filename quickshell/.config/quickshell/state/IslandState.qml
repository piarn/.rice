// Which page is open, and on which screen ("" = nothing open). A page
// lives on one of two surfaces (island/routes.js): the console in the
// middle of the screen (console/ConsoleWindow.qml: run, quick, sound,
// network, bluetooth, notifications, clipboard) or the island under the
// clock (island/Island.qml: the calendar); only one is open at a time.
// Names go through routes.js, so the old popup and IPC names (system,
// quicksettings, battery, commandcenter) still work.
pragma Singleton
import Quickshell
import Quickshell.I3
import QtQuick
import "../island/routes.js" as Routes

QtObject {
    id: root

    property string tab: ""
    property var screen: null
    // anything open, on any surface (island/routes.js)
    readonly property bool grown: tab !== ""
    readonly property string surface: Routes.surfaceOf(tab)
    readonly property bool islandOpen: surface === "island"
    readonly property bool consoleOpen: surface === "console"
    // run and clipboard hold the keyboard for as long as they're open
    readonly property bool wantsKeyboard: Routes.wantsKeyboard(tab)

    readonly property var focusedScreen: {
        const mon = I3.focusedMonitor
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (mon && screens[i].name === mon.name) return screens[i]
        return screens.length ? screens[0] : null
    }

    function open(name, scr) {
        const t = Routes.tabFor(name)
        if (!t) return
        screen = scr || focusedScreen
        tab = t
    }

    // what the run tab's search field starts with next time it opens, e.g.
    // ":" for the session actions ($mod+Shift+Escape, [power])
    property string runPrefix: ""

    function openRun(prefix, scr) {
        runPrefix = prefix || ""
        open("run", scr)
    }

    // the same tab on the same screen again collapses it
    function toggle(name, scr) {
        const t = Routes.tabFor(name)
        const target = scr || focusedScreen
        if (!t) return
        if (tab === t && screen === target) {
            close()
            return
        }
        screen = target
        tab = t
    }

    // a page handing keyboard focus back to its surface (console/Console.qml,
    // island/Panel.qml), e.g. when a password form closes
    signal panelFocusRequested()

    function close() {
        tab = ""
    }

    function step(delta) {
        if (grown) tab = Routes.step(tab, delta)
    }
}
