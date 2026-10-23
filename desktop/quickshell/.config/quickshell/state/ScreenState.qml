// The screen sway has focused, for the surfaces that open on "the current
// screen" (the launcher, toasts, the OSD).
pragma Singleton
import Quickshell
import Quickshell.I3
import QtQuick

Singleton {
    readonly property var focused: {
        const mon = I3.focusedMonitor
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (mon && screens[i].name === mon.name) return screens[i]
        return screens.length ? screens[0] : null
    }
}
