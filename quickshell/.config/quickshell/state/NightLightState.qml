// Night light from the control panel: while `active`, keeps wlsunset
// running pinned at `temperature` (low/high temps 1K apart, so it ignores
// the time of day). wlroots resets the gamma when the process exits, so
// turning it off — or quickshell restarting — restores normal colours. A
// new temperature restarts wlsunset, once the slider stops moving.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    property bool available: false
    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6000
    property int temperature: 4000

    function setTemperature(k) {
        temperature = Math.round(Math.max(minTemperature, Math.min(maxTemperature, k)) / 100) * 100
    }

    property bool restarting: false
    // a restart's own kill isn't a failure
    property real restartedAt: 0
    onTemperatureChanged: if (active) restart.restart()

    Timer {
        id: restart
        interval: 300
        onTriggered: {
            root.restartedAt = Date.now()
            root.restarting = true
            Qt.callLater(() => root.restarting = false)
        }
    }

    Process {
        running: root.active && root.available && !root.restarting
        command: ["wlsunset", "-t", String(root.temperature), "-T", String(root.temperature + 1)]
        onExited: (code) => { if (code !== 0 && Date.now() - root.restartedAt > 2000) root.active = false }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v wlsunset"]
        onExited: (code) => root.available = code === 0
    }
}
