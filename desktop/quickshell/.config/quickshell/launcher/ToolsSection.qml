// Data for the launcher's `!` (tools) mode: capture (screenshots,
// recording, color picker), the clipboard picker and silencing toasts.
import Quickshell
import QtQuick
import "../state"

Item {
    id: root

    readonly property string name: "tools"
    readonly property string glyph: "\u{f8cd}"   // build
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    readonly property var rows: [
        { kind: "header", title: "capture" },
        { kind: "action", group: "capture", key: "tool:shot-region", title: "screenshot region",
          glyph: "\u{ec08}", aliases: "screenshot capture crop satty print",
          subtitle: "freeze, crop, annotate · $mod+shift+s",
          run: () => Quickshell.execDetached([bin + "screenshot-region"]) },
        { kind: "toggle", group: "capture", key: "tool:record", title: "record screen",
          glyph: "\u{f679}", aliases: "recording video capture screenrec",
          on: () => RecorderState.recording,
          subtitle: () => RecorderState.recording ? "recording · " + RecorderState.elapsedText() : "window, region or monitor · $mod+shift+r",
          run: () => RecorderState.recording ? RecorderState.stop() : Quickshell.execDetached([bin + "screenrec"]) },
        { kind: "action", group: "capture", key: "tool:color", title: "color picker",
          glyph: "\u{e3b8}", aliases: "pick colour hex eyedropper",
          subtitle: "click a pixel, #hex to the clipboard",
          run: () => Quickshell.execDetached([bin + "color-pick"]) },
        { kind: "action", group: "capture", key: "tool:captures", title: "captures folder",
          glyph: "\u{e04a}", aliases: "screenshots recordings videos",
          subtitle: "~/Videos/Captures",
          run: () => Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Videos/Captures"]) },
        { kind: "header", title: "clipboard" },
        { kind: "action", group: "clipboard", key: "tool:clipboard", title: "clipboard history",
          glyph: "\u{e14f}", aliases: "cliphist paste copy",
          subtitle: "pick an entry to copy it back · $mod+v",
          run: () => Quickshell.execDetached([bin + "clip-pick"]) },
        { kind: "header", title: "notifications" },
        { kind: "toggle", group: "notifications", key: "tool:silence", title: "silence",
          glyph: "\u{e7f6}", aliases: "dnd do not disturb quiet",
          on: () => NotificationState.dnd, subtitle: () => NotificationState.dnd ? "toasts hidden" : "off",
          run: () => NotificationState.toggleDnd() },
    ]
}
