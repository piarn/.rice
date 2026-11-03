// Keeps windows 2px clear of the left and right edges of the ASUS XG49V, which
// crops about that much of its picture at both sides. Like Spacer: an exclusive
// zone, transparent, and it takes no input. Fullscreen windows still cover it.
// No other screen gets one.
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    required property var modelData
    readonly property int margin: 2

    Variants {
        model: root.modelData.model === "ASUS XG49V" ? ["left", "right"] : []
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
