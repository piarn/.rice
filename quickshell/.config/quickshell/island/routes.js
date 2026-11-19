.pragma library
// Where every page lives, and how names reach them. Two surfaces:
//  - console: the one centered surface ($mod+d; console/ConsoleWindow.qml)
//    with every page — run, quick, sound, network, bluetooth,
//    notifications, clipboard
//  - island: the calendar, dropping from the clock
// Plus the old popup/IPC names (system, quicksettings, battery, volume,
// commandcenter, ...) so sway binds and scripts keep working. No QML types,
// so it runs under node too.

const CONSOLE_TABS = ["run", "quick", "sound", "network", "bluetooth", "notifications", "clipboard"]
const ISLAND_TABS = ["calendar"]
const TABS = CONSOLE_TABS.concat(ISLAND_TABS)

// what the console's page row shows for each page
const LABELS = { run: "run", quick: "quick", sound: "sound", network: "net",
                 bluetooth: "bt", notifications: "notifs", clipboard: "clip" }

const ALIASES = {
    system: "quick",
    quicksettings: "quick",
    battery: "quick",
    audio: "sound",
    volume: "sound",
    mic: "sound",
    wifi: "network",
    net: "network",
    bt: "bluetooth",
    commandcenter: "run",
    launcher: "run"
}

// "" for a name that isn't a page
function tabFor(name) {
    return TABS.indexOf(name) >= 0 ? name : (ALIASES[name] || "")
}

// "console", "island", or "" for nothing open
function surfaceOf(tab) {
    if (CONSOLE_TABS.indexOf(tab) >= 0) return "console"
    if (ISLAND_TABS.indexOf(tab) >= 0) return "island"
    return ""
}

// the page `delta` places from `tab` on the same surface, wrapping
function step(tab, delta) {
    const list = surfaceOf(tab) === "island" ? ISLAND_TABS : CONSOLE_TABS
    const i = list.indexOf(tab)
    if (i < 0) return list[0]
    return list[(i + delta + list.length) % list.length]
}

// pages you type into, which hold the keyboard for as long as they're open
function wantsKeyboard(tab) {
    return tab === "run" || tab === "clipboard"
}
