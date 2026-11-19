// The readout's on/off light: a small filled square in the accent while on,
// an empty grey outline while off.
import QtQuick
import quickshell

Rectangle {
    property bool on: false
    width: 7
    height: 7
    color: on ? Colors.neon : "transparent"
    border.width: on ? 0 : Style.border
    border.color: Colors.gray
}
