// Shape language shared by every surface — the counterpart to the rice's
// Colors (which only carries the palette). Minimal and square: the top row
// floats on the wallpaper with no boxes; the control panel and the grown
// island are cards with square corners, and so is everything in them
// (tiles, chips, sliders, switches). The accent is spent only on what's
// active or focused. Every corner in the shell comes from the two radii
// below, so roundness is one change here.
pragma Singleton
import QtQuick

QtObject {
    // cards: the control panel, the grown island, the OSD, toasts
    readonly property int radius: 0
    // what sits inside a card: tiles, rows, chips, inputs, pills, knobs
    readonly property int round: 0
    readonly property int border: 1
    // the short accent bar beside an active row
    readonly property int marker: 2
    readonly property int pad: 14
    readonly property int gap: 8
    // where a row's or section header's content starts and ends inside a
    // tab: the last button of every row lines up at this distance from the
    // right edge, the first text at it from the left
    readonly property int inset: 8
    // the top row's height (workspaces, clock, icons)
    readonly property int barHeight: 30
    // Level steps: same 16 as the volume OSD and sway's volume keys.
    readonly property int segments: 16
    readonly property int fast: 80

    // the shell's text: Departure Mono, a pixel font drawn on an 11px grid, so
    // text stays at 11px (or 22) to keep it crisp; icons are Material Symbols
    readonly property string font: "Departure Mono"
    readonly property int fontSize: 11

    // a colour at some opacity, for faint fills (hover, active, chips)
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
