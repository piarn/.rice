// Shape language shared by every surface — the counterpart to the rice's
// Colors (which only carries the palette). "Quiet": text in two columns,
// space doing the work instead of lines and symbols. Labels grey, values
// white, "off" dim; groups separated by space alone; one pixel font; square
// corners; the accent only in slider fills and the text cursor. Motion is
// short and cheap (opacity and position only), every duration from here.
pragma Singleton
import QtQuick

QtObject {
    // cards: the console, the calendar, the OSD, toasts
    readonly property int radius: 0
    // what sits inside a card: rows, buttons, inputs
    readonly property int round: 0
    readonly property int border: 1
    readonly property int marker: 2
    readonly property int pad: 14
    readonly property int gap: 8
    // where a row's content starts and ends, left and right
    readonly property int inset: 10
    // the top row's height (workspaces, clock, readout)
    readonly property int barHeight: 30
    // Level steps: same 16 as the volume OSD and sway's volume keys.
    readonly property int segments: 16

    // motion: hover tints, slider glides / opening, the calendar
    readonly property int fast: 80
    readonly property int medium: 120

    // the console: a row, the space between groups, padding, width
    readonly property int rowHeight: 28
    readonly property int groupGap: 24
    readonly property int sectionGap: 24
    readonly property int consolePad: 22
    readonly property int consoleWidth: 600
    readonly property real labelSpacing: 0

    // the shell's text: Departure Mono, a pixel font drawn on an 11px grid, so
    // text stays at 11px (or 22) to keep it crisp; icons are Material Symbols
    readonly property string font: "Departure Mono"
    readonly property int fontSize: 11

    // a colour at some opacity, for faint fills (hover, selection)
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
