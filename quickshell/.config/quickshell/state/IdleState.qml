// "Keep awake" toggle from the console's quick page. island/Island.qml hangs an
// IdleInhibitor off each bar window bound to this, which is what swayidle
// honours (idle-inhibit protocol) — logind inhibitors don't stop it.
pragma Singleton
import QtQuick

QtObject {
    property bool inhibit: false
}
