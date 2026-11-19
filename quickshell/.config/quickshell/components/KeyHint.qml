// A row's key in the console, which-key style: the letter that acts on it,
// drawn faintly at the far right so it's there when you look for it and
// quiet otherwise.
import QtQuick
import quickshell

MonoText {
    property string key: ""
    property bool bright: false
    color: bright ? Colors.gray : Colors.dim
    text: key
}
