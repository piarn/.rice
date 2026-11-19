// Entry point: `quickshell` (or sway's `exec quickshell`) loads this as the
// "default" config since it sits directly at ~/.config/quickshell/shell.qml.
// Colors are Catppuccin Mocha, in theme/quickshell/Colors.qml. Ported from
// github.com/piarn/.rice at 4156a09, without the greeter and theme switcher.
//
// Layout: per screen three pieces along the top — the workspaces (top left),
// the Island in the center (island/: collapsed it's the date and time; grown,
// the tabbed Panel for calendar and clipboard, island/tabs/), the status
// icons (top right) — plus a Spacer reserving their height; a SideWindow
// under the right piece (panel/: the control panel — quick, sound, network,
// bluetooth, notifications, panel/tabs/); and a LauncherWindow in the middle
// of the screen (launcher/: the run box, $mod+d). Which tab is open where,
// and so which surface shows, is IslandState (island/routes.js). state/
// holds the pragma-Singleton status backends; popups/ the free-standing
// surfaces (LockScreen, toasts, OSD); components/ shared UI pieces.
import Quickshell
import Quickshell.Io
import QtQuick
import "./popups"
import "./state"
import "./island"
import "./panel"
import "./launcher"

ShellRoot {
    // No hot reload on file changes: reloading mid-edit has crashed
    // quickshell (EGL surface errors), which while locked leaves sway's red
    // lock-failure screen. Apply changes with $mod+Shift+c instead.
    settings.watchFiles: false

    // Every tab exists once, here; the open screen's Island, SideWindow or
    // LauncherWindow adopts its surface's tabs and hands them back here when
    // it closes.
    Item {
        visible: false
        Panel { id: sharedPanel }
        SidePanel { id: sharedSidePanel }
        Launcher { id: sharedLauncher }
    }

    Variants {
        model: Quickshell.screens
        delegate: SideWindow { panel: sharedSidePanel }
    }
    Variants {
        model: Quickshell.screens
        delegate: LauncherWindow { launcher: sharedLauncher }
    }

    Variants {
        model: Quickshell.screens
        delegate: Spacer {}
    }
    Variants {
        model: Quickshell.screens
        delegate: EdgeMargins {}
    }
    Variants {
        model: Quickshell.screens
        delegate: Island { panel: sharedPanel }
    }
    // the workspaces (top left) and status icons (top right), each a card
    Variants {
        model: Quickshell.screens
        delegate: Card {
            Workspaces {}
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Card {
            id: statusCard
            rightSide: true
            StatusIcons { screen: statusCard.modelData }
        }
    }

    NotificationToasts {}
    Osd {}
    LockScreen {}

    // `qs ipc call popup toggle <name>` — a control panel tab (quick, sound,
    // network, bluetooth, notifications), an island tab (calendar, run,
    // clipboard) or an old name (system/quicksettings/battery → quick; see
    // island/routes.js). Opens on the focused monitor.
    IpcHandler {
        target: "popup"
        function toggle(name: string): void { IslandState.toggle(name) }
        function close(): void { IslandState.close() }
    }

    // `qs ipc call vpn toggle mullvad` — connect/disconnect a VPN provider
    // extra by name (see state/ExtrasState.qml), e.g. from a sway bind.
    IpcHandler {
        target: "vpn"
        function toggle(name: string): void {
            const v = ExtrasState.vpn(name)
            if (v && v.available) v.toggle()
        }
    }

    // `qs ipc call idle toggle` — the quick settings "keep awake" tile.
    IpcHandler {
        target: "idle"
        function toggle(): void { IdleState.inhibit = !IdleState.inhibit }
    }

    // Liveness signal for ~/.local/bin/qs-watchdog, which SIGKILLs and
    // restarts quickshell once this goes stale (a hung instance with a
    // popup open would otherwise hold all input hostage).
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

    // Sway's brightness keys (`qs ipc call brightness up`); see
    // state/BrightnessState.qml for why this isn't brightnessctl.
    IpcHandler {
        target: "brightness"
        function up(): void { BrightnessState.adjust(BrightnessState.step) }
        function down(): void { BrightnessState.adjust(-BrightnessState.step) }
    }
}
