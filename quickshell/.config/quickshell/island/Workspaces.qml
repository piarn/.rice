// The top row's left piece: workspaces 1–5 always, plus any higher one that
// exists. Empty ones faint, ones with windows soft grey, the focused one
// bright with the accent underline; an urgent one red. Click to go there.
import Quickshell.I3
import QtQuick
import quickshell
import "../state"
import "../components"

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Style.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

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
                readonly property bool focused: ws !== null && ws.focused
                width: Math.max(24, label.implicitWidth + 12)
                height: 26
                radius: Style.round
                color: wsMouse.containsMouse ? Style.tint(Colors.fg, 0.06) : "transparent"

                MonoText {
                    id: label
                    anchors.centerIn: parent
                    font.pixelSize: Style.fontSize
                    color: !parent.ws ? Colors.dim
                        : parent.ws.urgent ? Colors.red
                        : parent.focused ? Colors.fg : Colors.gray
                    text: modelData
                }

                // where you are: the accent underline
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: parent.focused ? 12 : 0
                    height: 2
                    color: Colors.neon
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        IslandState.close()
                        if (parent.ws) parent.ws.activate()
                        else I3.dispatch("workspace number " + parent.modelData)
                    }
                }
            }
        }
    }
}
