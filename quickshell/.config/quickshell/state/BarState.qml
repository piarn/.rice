// How the top row is laid out: "wide" (workspaces at the left edge, readout at
// the right edge) or "centered" (all three pieces pulled in around the clock,
// for an ultrawide where the edges are too far apart). Per machine, kept in
// quickshell's state dir and switched from the console's settings (`bar`).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string style: "wide"
    readonly property bool centered: style === "centered"

    function set(s) {
        style = s === "centered" ? "centered" : "wide"
        file.setText(style)
    }

    FileView {
        id: file
        path: Quickshell.statePath("bar-style")
        printErrors: false
        onLoaded: root.style = text().trim() === "centered" ? "centered" : "wide"
    }
}
