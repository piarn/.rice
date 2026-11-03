// Catppuccin Mocha, mauve accent, as the `quickshell` QML module
// (QML2_IMPORT_PATH=~/.config/quickshell/theme): `import quickshell` then
// Colors.<role>. Same roles and values as tmux/.config/tmux/theme.conf.
pragma Singleton
import QtQuick

QtObject {
    readonly property color black: "#1e1e2e"    // base
    readonly property color surface: "#313244"  // surface0
    readonly property color fg: "#cdd6f4"       // text
    readonly property color white: "#f5e0dc"    // rosewater

    readonly property color neon: "#cba6f7"     // mauve
    readonly property color acid: "#f5c2e7"     // pink
    readonly property color dim: "#45475a"      // surface1
    readonly property color deep: "#313244"     // surface0
    readonly property color gray: "#6c7086"     // overlay0
    readonly property color gray2: "#a6adc8"    // subtext0

    readonly property color red: "#f38ba8"
    readonly property color amber: "#f9e2af"    // yellow
    readonly property color blue: "#89b4fa"
    readonly property color magenta: "#cba6f7"  // mauve
    readonly property color cyan: "#94e2d5"     // teal
}
