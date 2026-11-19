// One of the strip's status icons. Left click opens its tab in the side
// panel (`clicked`); right or middle click does its quick action
// (`toggled`: mute, silence, bluetooth power, ...); the wheel steps it. A
// tooltip shows under it on hover (a PopupWindow anchored to the icon, so it
// can leave the strip's bounds), hidden while anything is open. `active`
// marks the icon whose tab is open right now.
import Quickshell
import QtQuick
import quickshell
import "../state"
import "../components"

Item {
    id: q

    property alias glyph: icon.text
    property color tint: Colors.gray2
    property string tip: ""
    property bool active: false
    // tests: show the tooltip without a pointer
    property bool forceTip: false

    signal clicked()
    signal toggled()
    signal wheeled(int steps)

    implicitWidth: 28
    implicitHeight: 28

    // a faint hover fill; the open tab's icon is brighter with the accent
    // underline every "you are here" mark in the shell uses
    Rectangle {
        anchors.fill: parent
        radius: Style.round
        color: mouse.containsMouse ? Style.tint(Colors.fg, 0.06) : "transparent"
    }
    Rectangle {
        visible: q.active
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 12
        height: 2
        color: Colors.neon
    }

    Icon {
        id: icon
        anchors.centerIn: parent
        font.pixelSize: 15
        color: q.active || mouse.containsMouse ? Colors.fg : q.tint
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => m.button === Qt.LeftButton ? q.clicked() : q.toggled()
        onWheel: (w) => q.wheeled(w.angleDelta.y > 0 ? 1 : -1)
    }

    PopupWindow {
        id: tipWindow
        // Only grows while shown (resets once hidden): a quick action changes
        // the text ("volume 59%" → "muted"), and a shrinking, re-centering
        // tooltip jumps under the pointer.
        property real widest: 0
        anchor.item: q
        anchor.rect.x: q.width / 2 - implicitWidth / 2
        anchor.rect.y: q.height + 10
        visible: q.tip !== "" && (q.forceTip || (mouse.containsMouse && !IslandState.grown))
        readonly property real needed: tipText.implicitWidth + 16
        onVisibleChanged: widest = visible ? needed : 0
        onNeededChanged: if (visible) widest = Math.max(widest, needed)
        implicitWidth: Math.max(widest, needed)
        implicitHeight: tipText.implicitHeight + 12
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Style.round
            color: Colors.mantle
            border.width: Style.border
            border.color: Colors.surface

            MonoText {
                id: tipText
                anchors.centerIn: parent
                color: Colors.fg
                text: q.tip
            }
        }
    }
}
