// Keeps windows 2px clear of the left and right edges of the ASUS XG49V, which
// crops about that much of its picture at both sides. Like Spacer: an exclusive
// zone, transparent, and it takes no input. Fullscreen windows still cover it.
// Quickshell can't see a screen's make or model under sway (it reports
// "Unknown"), so the screen is recognized by its 3840x1080 size, which no other
// display here has.
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    required property var modelData
    readonly property int margin: 2

    Variants {
        model: root.modelData.width === 3840 && root.modelData.height === 1080 ? ["left", "right"] : []
        delegate: PanelWindow {
            required property string modelData

            screen: root.modelData
            anchors { top: true; bottom: true; left: modelData === "left"; right: modelData === "right" }
            implicitWidth: root.margin
            exclusiveZone: root.margin
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-edge"
        }
    }
}
