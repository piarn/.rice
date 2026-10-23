// Screen layouts (~/.rice/layouts), which of them the connected outputs
// satisfy, and the current one — for the launcher's `:layout` mode.
// Read with one python3 pass on refresh(), once at startup and after a
// switch; applying goes through ~/.rice/bin/apply-layout.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.rice"

    property var layouts: []    // [id]
    property var usableLayouts: []   // [id] whose `# requires:` outputs are all connected
    property string currentLayout: ""

    function refresh() { readProc.running = true }

    function applyLayout(id) {
        applyProc.command = [dir + "/bin/apply-layout", id]
        applyProc.running = true
    }

    Process {
        id: applyProc
        onExited: root.refresh()
    }

    Process {
        id: readProc
        command: ["python3", "-c", `
import json, os, re, subprocess, sys
d = sys.argv[1]
def first(p):
    try:
        return open(p).readline().strip()
    except OSError:
        return ""
layouts = sorted(f[:-5] for f in os.listdir(d + "/layouts") if f.endswith(".conf"))
# same matching as ~/.rice/bin/apply-layout: connector name or "make model serial"
connected = set()
try:
    for o in json.loads(subprocess.run(["swaymsg", "-t", "get_outputs"], capture_output=True, text=True).stdout):
        connected.add(o["name"])
        if o.get("make") and o.get("model") and o.get("serial"):
            connected.add(f"{o['make']} {o['model']} {o['serial']}")
except (OSError, ValueError):
    pass
def requires(l):
    for line in open(d + "/layouts/" + l + ".conf"):
        m = re.match(r"#\\s*requires:\\s*(.+)$", line.strip(), re.I)
        if m:
            return {x.strip() for x in m.group(1).split(",") if x.strip()}
    return set()
usable = [l for l in layouts if requires(l) and requires(l) <= connected]
print(json.dumps({"layouts": layouts, "usable": usable, "layout": first(d + "/layouts/current")}))
`, dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text)
                    root.layouts = r.layouts
                    root.usableLayouts = r.usable
                    root.currentLayout = r.layout
                } catch (e) {
                    console.warn("LayoutState: " + e)
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
