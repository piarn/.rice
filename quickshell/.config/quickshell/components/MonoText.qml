// The shell's body text: monospace, 12px, foreground color.
import QtQuick
import quickshell

Text {
    font.family: Style.font
    // hinted, unsmoothed edges: a pixel font stays on its pixels
    renderType: Text.NativeRendering
    font.pixelSize: Style.fontSize
    color: Colors.fg
}
