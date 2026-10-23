// The status bar: one thin full-width line at the top of each screen, text
// only.
//  - left: workspaces 1–5 always (empty ones dim), plus any other that
//    exists; the focused one inverted, an urgent one red. Click to go there.
//  - center: time and date
//  - right: recording (click stops it), "silenced" while toasts are off,
//    network (click: the launcher's network mode), volume (click mutes, wheel steps), battery,
//    and ● while there are unread notifications (click clears them).
// Anything that needs attention (offline, weak wi-fi, low battery) turns
// amber or red; everything else stays gray.
import Quickshell
import Quickshell.I3
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import quickshell
import "../components"
import "../state"

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 22
    color: Colors.black
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // "keep awake" (`qs ipc call idle toggle`): the bar is always mapped,
    // which is what the idle-inhibit protocol needs from the inhibitor.
    IdleInhibitor {
        window: bar
        enabled: IdleState.inhibit
    }

    readonly property real pct: UPower.displayDevice.percentage * 100
    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery && !charging
        && UPower.displayDevice.state !== UPowerDeviceState.FullyCharged

    component Seg: MonoText {
        font.pixelSize: 12
        color: Colors.gray2
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // a 1px rule under the bar, like tmux's status line has above it
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Style.border
        color: Colors.dim
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            // "1".."5", then any other workspace that exists — except
            // `mirror`, the present layout's HDMI-only wl-mirror holder
            model: {
                const names = ["1", "2", "3", "4", "5"]
                for (const w of I3.workspaces.values)
                    if (names.indexOf(w.name) < 0 && w.name !== "mirror") names.push(w.name)
                return names
            }

            delegate: Rectangle {
                required property string modelData
                readonly property var ws: I3.workspaces.values.find(w => w.name === modelData) || null
                width: label.implicitWidth + 14
                height: bar.implicitHeight - Style.border
                color: ws && ws.focused ? Colors.neon : ws && ws.urgent ? Colors.red : "transparent"

                MonoText {
                    id: label
                    anchors.centerIn: parent
                    font.pixelSize: 12
                    color: !parent.ws ? Colors.dim
                        : parent.ws.focused || parent.ws.urgent ? Colors.black : Colors.gray2
                    text: modelData
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (parent.ws) parent.ws.activate()
                        else I3.dispatch("workspace number " + parent.modelData)
                    }
                }
            }
        }
    }

    Seg {
        id: clock
        anchors.centerIn: parent
        color: Colors.fg
        text: Qt.formatDateTime(new Date(), "HH:mm  ddd d MMM").toLowerCase()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm  ddd d MMM").toLowerCase()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Seg {
            visible: RecorderState.recording
            color: Colors.red
            text: "● rec " + RecorderState.elapsedText()
            MouseArea { anchors.fill: parent; onClicked: RecorderState.stop() }
        }

        Seg {
            visible: NotificationState.dnd
            color: Colors.amber
            text: "silenced"
            MouseArea { anchors.fill: parent; onClicked: NotificationState.toggleDnd() }
        }

        Seg {
            readonly property var p: NetworkState.primary
            readonly property bool weak: NetworkState.kind === "wifi" && NetworkState.signal < 50
            color: NetworkState.kind === "none" || (weak && NetworkState.signal < 25) ? Colors.red
                : weak ? Colors.amber : Colors.gray2
            text: {
                if (!p || !p.connected) return NetworkState.wifiEnabled ? "offline" : "wifi off"
                if (p.type === "wifi") return "wifi " + p.signal + "%"
                return p.type === "wwan" ? "mobile" : "eth"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/qs", "ipc", "call", "commandcenter", "open", "#"])
            }
        }

        Seg {
            readonly property var audio: VolumeState.sinkAudio
            color: audio && audio.muted ? Colors.gray : Colors.gray2
            text: !audio ? "no audio" : audio.muted ? "muted" : "vol " + Math.round(audio.volume * 100) + "%"
            MouseArea {
                anchors.fill: parent
                onClicked: VolumeState.toggleMute(parent.audio)
                onWheel: (wheel) => VolumeState.adjustVolume((wheel.angleDelta.y > 0 ? 1 : -1) / Style.segments)
            }
        }

        Seg {
            visible: UPower.displayDevice.isLaptopBattery
            color: bar.onBattery && bar.pct <= 15 ? Colors.red
                : bar.onBattery && bar.pct <= 30 ? Colors.amber : Colors.gray2
            text: "bat " + Math.round(bar.pct) + "%" + (bar.charging ? "+" : "")
        }

        Seg {
            visible: NotificationState.notifications.length > 0
            color: Colors.fg
            text: "●"
            MouseArea { anchors.fill: parent; onClicked: NotificationState.clearAll() }
        }
    }
}
