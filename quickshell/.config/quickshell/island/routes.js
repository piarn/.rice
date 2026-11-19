.pragma library
// Where every tab lives, and how names reach them. Three surfaces:
//  - panel: the control panel on the right edge (panel/SideWindow.qml), for
//    settings: quick, sound, network, bluetooth, notifications
//  - island: the center of the top row grows under the clock: calendar,
//    clipboard
//  - launcher: the run box ($mod+d), in the middle of the screen
//    (launcher/LauncherWindow.qml)
// Plus the old popup/IPC names (system, quicksettings, battery,
// commandcenter) so sway binds and scripts keep working. No QML types, so it
// runs under node too.

const PANEL_TABS = ["quick", "sound", "network", "bluetooth", "notifications"]
const ISLAND_TABS = ["calendar", "clipboard"]
const LAUNCHER_TABS = ["run"]
const TABS = PANEL_TABS.concat(ISLAND_TABS, LAUNCHER_TABS)

const ALIASES = {
    system: "quick",
    quicksettings: "quick",
    battery: "quick",
    audio: "sound",
    volume: "sound",
    mic: "sound",
    wifi: "network",
    commandcenter: "run"
}

// "" for a name that isn't a tab
function tabFor(name) {
    return TABS.indexOf(name) >= 0 ? name : (ALIASES[name] || "")
}

// "panel", "island", "launcher", or "" for nothing open
function surfaceOf(tab) {
    if (PANEL_TABS.indexOf(tab) >= 0) return "panel"
    if (ISLAND_TABS.indexOf(tab) >= 0) return "island"
    if (LAUNCHER_TABS.indexOf(tab) >= 0) return "launcher"
    return ""
}

// the tab `delta` places from `tab` on the same surface, wrapping
function step(tab, delta) {
    const surface = surfaceOf(tab)
    const list = surface === "island" ? ISLAND_TABS : surface === "launcher" ? LAUNCHER_TABS : PANEL_TABS
    const i = list.indexOf(tab)
    if (i < 0) return list[0]
    return list[(i + delta + list.length) % list.length]
}

// tabs you type into, which hold the keyboard for as long as they're open
function wantsKeyboard(tab) {
    return tab === "run" || tab === "clipboard"
}
