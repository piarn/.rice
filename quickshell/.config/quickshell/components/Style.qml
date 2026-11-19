// Shape language shared by every surface — the counterpart to the rice's
// Colors (which only carries the palette). "Console": a flight readout set
// in one pixel font. Information is typography — labels on the left, a
// dotted leader, values on the right, a small square light for on/off —
// with section titles in spaced capitals, square corners, 1px rules, lots of
// space, and the accent spent only on "on" lights and the underline that
// marks where you are. Every corner comes from the two radii below.
pragma Singleton
import QtQuick

QtObject {
    // cards: the console, the calendar island, the OSD, toasts
    readonly property int radius: 0
    // what sits inside a card: rows, chips, inputs
    readonly property int round: 0
    readonly property int border: 1
    // the short accent bar beside the selected row
    readonly property int marker: 2
    readonly property int pad: 14
    readonly property int gap: 8
    // where a row's or section header's content starts and ends: the last
    // column of every row lines up at this distance from the right edge, the
    // first text at it from the left
    readonly property int inset: 8
    // the top row's height (workspaces, clock, readout)
    readonly property int barHeight: 30
    // Level steps: same 16 as the volume OSD and sway's volume keys.
    readonly property int segments: 16
    readonly property int fast: 80

    // the console: a readout row, the space above a section, its padding, width
    readonly property int rowHeight: 26
    readonly property int sectionGap: 18
    readonly property int consolePad: 20
    readonly property int consoleWidth: 640
    // spaced capitals for section titles
    readonly property real labelSpacing: 2

    // the shell's text: Departure Mono, a pixel font drawn on an 11px grid, so
    // text stays at 11px (or 22) to keep it crisp; icons are Material Symbols
    readonly property string font: "Departure Mono"
    readonly property int fontSize: 11

    // a colour at some opacity, for faint fills (hover, selection)
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
