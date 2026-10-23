// Entry point: `quickshell` (sway's exec_always) loads this as the default
// config, since it sits directly at ~/.config/quickshell/shell.qml. The
// palette is the `quickshell` module in theme/ (Colors.qml), found through
// QML2_IMPORT_PATH.
//
// Layout: bar/ is the status bar (one per screen); launcher/ the launcher
// ($mod+d); popups/ the lock screen, notification toasts and the OSD;
// state/ the pragma-Singleton backends; components/ shared pieces.
// greeter.qml beside this is the login screen, a separate config.
import Quickshell
import Quickshell.Io
import QtQuick
import "./bar"
import "./launcher"
import "./popups"
import "./state"

ShellRoot {
    // No hot reload on file changes: reloading mid-edit has crashed
    // quickshell (EGL surface errors), which while locked leaves sway's red
    // lock-failure screen. Apply changes with $mod+Shift+c instead.
    settings.watchFiles: false

    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    Launcher {}
    NotificationToasts {}
    Osd {}
    LockScreen {}

    // `qs ipc call idle toggle` — keep the screen awake.
    IpcHandler {
        target: "idle"
        function toggle(): void { IdleState.inhibit = !IdleState.inhibit }
    }

    // Sway's brightness keys (`qs ipc call brightness up`); see
    // state/BrightnessState.qml for why this isn't brightnessctl.
    IpcHandler {
        target: "brightness"
        function up(): void { BrightnessState.adjust(BrightnessState.step) }
        function down(): void { BrightnessState.adjust(-BrightnessState.step) }
    }

    // Liveness signal for ~/.local/bin/qs-watchdog, which SIGKILLs and
    // restarts quickshell once this goes stale (a hung instance with the
    // launcher open would otherwise hold all input hostage).
    FileView {
        id: heartbeat
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-heartbeat"
        printErrors: false
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: heartbeat.setText(Date.now() + "\n")
    }
}
