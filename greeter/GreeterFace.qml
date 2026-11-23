// One screen of the login: the lock screen's face (seven-segment clock,
// date, 16 password cells), with a user line above the cells and the
// session and keys under them. All state lives on shell.qml (`greeter`);
// this only shows it and feeds keystrokes back.
//
//   Tab / Shift+Tab   user <-> password
//   Enter             next field, then log in
//   F1 / F2           power off / reboot
//   F3, Ctrl+←/→      session
import QtQuick
import quickshell
import "./components"

Rectangle {
    id: root

    required property var greeter

    color: Colors.black

    function focusField() {
        (greeter.user === "" ? userInput : passInput).forceActiveFocus()
    }
    Component.onCompleted: Qt.callLater(focusField)
    MouseArea { anchors.fill: parent; onClicked: root.focusField() }

    // F-keys and Ctrl+arrows reach here from whichever field has focus.
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F1) greeter.power("poweroff")
        else if (e.key === Qt.Key_F2) greeter.power("reboot")
        else if (e.key === Qt.Key_F3) greeter.cycleSession(1)
        else if (e.key === Qt.Key_Left && e.modifiers & Qt.ControlModifier) greeter.cycleSession(-1)
        else if (e.key === Qt.Key_Right && e.modifiers & Qt.ControlModifier) greeter.cycleSession(1)
        else if (e.key === Qt.Key_Escape && greeter.preview) Qt.quit()
        else return
        e.accepted = true
    }

    Connections {
        target: root.greeter
        function onRejected() { rejectAnim.restart(); passInput.forceActiveFocus() }
        // Assigned rather than bound (a TextInput's binding breaks on the
        // first keystroke), so every screen follows the one being typed on.
        function onUserChanged() { if (userInput.text !== root.greeter.user) userInput.text = root.greeter.user }
        function onPasswordChanged() { if (passInput.text !== root.greeter.password) passInput.text = root.greeter.password }
    }

    // a field's left rule: accent when focused, red after a failure
    component Rule: Rectangle {
        property bool active
        width: Style.marker
        height: 16
        color: active && root.greeter.failed ? Colors.red : active ? Colors.neon : Colors.dim
    }

    Column {
        anchors.centerIn: parent
        spacing: 36

        Row {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            readonly property int h: root.greeter.now.getHours()
            readonly property int m: root.greeter.now.getMinutes()

            SegmentDigit { value: Math.floor(clock.h / 10) }
            SegmentDigit { value: clock.h % 10 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 40
                Repeater {
                    model: 2
                    Rectangle {
                        width: 13
                        height: 13
                        color: root.greeter.now.getSeconds() % 2 === 0 ? Colors.neon : Colors.deep
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
            SegmentDigit { value: Math.floor(clock.m / 10) }
            SegmentDigit { value: clock.m % 10 }
        }

        MonoText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 14
            font.letterSpacing: 2
            color: Colors.gray2
            text: Qt.formatDate(root.greeter.now, "dddd · d MMMM").toLowerCase()
        }

        Column {
            id: form
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            // same width as the cell row below, so both rules line up
            readonly property int fieldWidth: Style.marker + Style.pad + cells.width

            // user: a plain visible field
            Item {
                width: form.fieldWidth
                height: 16

                Rule { active: userInput.activeFocus }

                TextInput {
                    id: userInput
                    x: Style.marker + Style.pad
                    width: parent.width - x
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    color: Colors.fg
                    selectionColor: Colors.dim
                    cursorDelegate: Rectangle {
                        width: 8
                        color: userInput.activeFocus ? Colors.neon : "transparent"
                    }
                    enabled: !root.greeter.busy
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    onTextChanged: root.greeter.user = text

                    MonoText {
                        visible: userInput.text === ""
                        x: 12   // clear of the block cursor
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 14
                        color: Colors.gray
                        text: "user"
                    }

                    Keys.onTabPressed: passInput.forceActiveFocus()
                    Keys.onReturnPressed: passInput.forceActiveFocus()
                    Keys.onEnterPressed: passInput.forceActiveFocus()
                }
            }

            // password: 16 cells that light up per character
            Item {
                id: field
                width: form.fieldWidth
                height: 16

                Rule { active: passInput.activeFocus }

                Row {
                    id: cells
                    x: Style.marker + Style.pad
                    spacing: 4

                    readonly property int filled: Math.min(passInput.length, Style.segments)
                    property bool flash: false

                    Repeater {
                        model: Style.segments
                        Rectangle {
                            width: 14
                            height: 16
                            color: cells.flash ? Colors.red
                                : root.greeter.busy && index < cells.filled ? Colors.acid
                                : index < cells.filled ? Colors.neon : Colors.deep
                            Behavior on color { ColorAnimation { duration: Style.fast } }
                        }
                    }
                }

                TextInput {
                    id: passInput
                    width: 1
                    height: 1
                    opacity: 0
                    echoMode: TextInput.Password
                    enabled: !root.greeter.busy
                    onTextChanged: root.greeter.password = text
                    Keys.onBacktabPressed: userInput.forceActiveFocus()
                    Keys.onTabPressed: userInput.forceActiveFocus()
                    Keys.onReturnPressed: root.greeter.login()
                    Keys.onEnterPressed: root.greeter.login()
                }

                SequentialAnimation {
                    id: rejectAnim
                    PropertyAction { target: cells; property: "flash"; value: true }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -6; duration: 40 }
                    NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
                    PauseAnimation { duration: 400 }
                    PropertyAction { target: cells; property: "flash"; value: false }
                }
            }

            // Fixed height: an empty status mustn't shift the layout.
            MonoText {
                width: form.fieldWidth
                height: 16
                horizontalAlignment: Text.AlignHCenter
                color: root.greeter.failed ? Colors.red : Colors.amber
                text: root.greeter.busy ? "verifying…"
                    : root.greeter.status !== "" ? root.greeter.status
                    : passInput.length > Style.segments ? passInput.length + " chars" : ""
            }
        }

        // the session, and the keys, as one tmux-like status line
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            Row {
                spacing: 8
                MonoText { color: Colors.neon; text: "‹" }
                MonoText {
                    color: Colors.fg
                    text: root.greeter.session ? root.greeter.session.name.toLowerCase() : "no session"
                }
                MonoText { color: Colors.neon; text: "›" }
            }

            Repeater {
                model: [["F1", "poweroff"], ["F2", "reboot"], ["F3", "session"]]
                    .concat(root.greeter.preview ? [["Esc", "quit preview"]] : [])
                Row {
                    required property var modelData
                    spacing: 6
                    MonoText { color: Colors.neon; text: modelData[0] }
                    MonoText { color: Colors.gray; text: modelData[1] }
                }
            }
        }
    }
}
