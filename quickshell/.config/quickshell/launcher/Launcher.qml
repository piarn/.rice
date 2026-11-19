// The launcher's contents: the run box ($mod+d; island/tabs/RunTab.qml —
// search, apps, the prefix modes). Created once (shell.qml) so the tab, its
// state and its IPC handler exist once; whichever screen's LauncherWindow is
// open adopts it.
import QtQuick
import quickshell
import "../state"
import "../island/tabs"

FocusScope {
    id: launcher

    implicitHeight: runTab.implicitHeight
    // it's a text box: always the keyboard
    readonly property bool needsKeyboard: true

    function focusCurrent() {
        if (runTab.initialFocus) runTab.initialFocus.forceActiveFocus()
    }

    Connections {
        target: IslandState
        function onTabChanged() { if (IslandState.launcherOpen) Qt.callLater(launcher.focusCurrent) }
    }

    RunTab { id: runTab; width: parent.width }
}
