// The fixed palette, as the `quickshell` QML module (QML2_IMPORT_PATH=
// ~/.config/quickshell/theme): `import quickshell` then Colors.<role>.
pragma Singleton
import QtQuick

QtObject {
    readonly property color black: "#0b0b0b"
    readonly property color surface: "#161616"
    readonly property color fg: "#d0d0d0"
    readonly property color white: "#f2f2f2"

    readonly property color neon: "#bdbdbd"
    readonly property color acid: "#e6e6e6"
    readonly property color dim: "#2c2c2c"
    readonly property color deep: "#1c1c1c"
    readonly property color gray: "#5f5f5f"
    readonly property color gray2: "#858585"

    readonly property color red: "#c46a6a"
    readonly property color amber: "#c2a061"
    readonly property color blue: "#7f93ad"
    readonly property color magenta: "#a08aad"
    readonly property color cyan: "#7fa8a3"
}
