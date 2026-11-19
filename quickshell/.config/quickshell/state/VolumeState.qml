// Speaker, mic, every audio device and every app's stream. Reads come from
// Quickshell.Services.Pipewire, whose reactive properties just work; writes
// go through wpctl, same as sway's volume keys. Writing PwNodeAudio.volume
// directly was unreliable on a Bluetooth (a2dp) sink — a +0.06 write landed
// as +0.25 — so every slider/wheel/mute action shells out instead.
// PwObjectTracker is what makes a node's .audio live instead of stale: the
// defaults are always tracked, everything else only while the sound tab is
// open (`trackAll`).
//
// What pipewire's own API doesn't offer comes from pactl (pipewire-pulse):
// each card's profiles (a headset's a2dp vs. headset mode) and moving an app
// to another output. Read on demand by refreshExtras().
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: root

    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var sourceAudio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    readonly property string sinkName: nodeName(Pipewire.defaultAudioSink)
    readonly property string sourceName: nodeName(Pipewire.defaultAudioSource)

    // Pipewire.nodes carries every node pipewire knows about — playback
    // streams (individual apps), capture streams, and the actual hardware
    // sinks/sources. isStream tells them apart; sources additionally drop
    // each sink's ".monitor" node, which is a source in pipewire's eyes but
    // not one a person would ever want as their mic.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n =>
        !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource) && !n.name.endsWith(".monitor"))
    // apps playing sound, and apps recording (using a mic)
    readonly property var playback: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && (n.type & PwNodeType.Audio))
    readonly property var recording: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && (n.type & PwNodeType.Audio))

    // the sound tab sets this while it's open
    property bool trackAll: false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    PwObjectTracker {
        objects: root.trackAll ? root.sinks.concat(root.sources, root.playback, root.recording) : []
    }

    function nodeName(node) {
        if (!node) return ""
        return node.nickname || node.description || node.name
    }

    // an app stream's name: the app, then what it's playing if that says more
    function streamTitle(node) {
        const p = node.properties || {}
        return p["application.name"] || p["application.process.binary"] || node.description || node.name
    }
    function streamDetail(node) {
        const p = node.properties || {}
        const media = p["media.name"] || ""
        return media && media !== streamTitle(node) ? media : ""
    }

    // Writing the "preferred" node (rather than defaultAudioSink/-Source,
    // which are read-only — they just reflect whatever the preferred one
    // resolves to) is what actually asks wireplumber to switch.
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node }
    function setSource(node) { Pipewire.preferredDefaultAudioSource = node }

    function speakerIcon() {
        if (!root.sinkAudio) return "\u{e04e}"   // volume_mute
        if (root.sinkAudio.muted) return "\u{e04f}"   // volume_off
        const v = root.sinkAudio.volume
        if (v <= 0) return "\u{e04e}"
        if (v < 0.34) return "\u{e04d}"   // volume_down
        if (v < 0.67) return "\u{e79c}"   // volume_down_alt
        return "\u{e050}"   // volume_up
    }

    function micIcon() {
        if (!root.sourceAudio) return "\u{e02b}"   // mic_off
        return root.sourceAudio.muted ? "\u{e02b}" : "\u{e31d}"   // mic
    }

    function toggleMute(audio) {
        if (!audio) return
        const target = audio === root.sourceAudio ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@"
        Quickshell.execDetached(["wpctl", "set-mute", target, "toggle"])
    }

    // Slider drags fire far faster than wpctl runs, so each writer keeps
    // only the newest value queued. `target` remembers what was last asked
    // for until the writer goes idle, so quick wheel steps build on each
    // other instead of on a readback that hasn't caught up yet.
    function setVolume(input, v) {
        const w = input ? sourceWriter : sinkWriter
        w.target = Math.max(0, Math.min(1, v))
        const cmd = ["wpctl", "set-volume", input ? "@DEFAULT_AUDIO_SOURCE@" : "@DEFAULT_AUDIO_SINK@", w.target.toFixed(4)]
        if (w.running) {
            w.pending = cmd
        } else {
            w.command = cmd
            w.running = true
        }
    }

    function adjust(input, delta) {
        const w = input ? sourceWriter : sinkWriter
        const audio = input ? root.sourceAudio : root.sinkAudio
        if (!audio) return
        setVolume(input, (w.target >= 0 ? w.target : audio.volume) + delta)
    }

    function adjustVolume(delta) { adjust(false, delta) }
    function adjustMicVolume(delta) { adjust(true, delta) }

    component VolumeWriter: Process {
        property var pending: null
        property real target: -1
        onExited: {
            if (pending) {
                command = pending
                pending = null
                running = true
            } else {
                target = -1
            }
        }
    }

    VolumeWriter { id: sinkWriter }
    VolumeWriter { id: sourceWriter }

    // Any node by id: a device that isn't the default, or an app's stream.
    // One writer for all of them, keeping only the newest value per node.
    property var nodeTargets: ({})   // id -> last requested volume, while queued
    property var nodeQueue: ({})     // id -> volume still to write

    function setNodeVolume(node, v) {
        if (!node) return
        const vol = Math.max(0, Math.min(1, v))
        const t = Object.assign({}, nodeTargets); t[node.id] = vol; nodeTargets = t
        const q = Object.assign({}, nodeQueue); q[node.id] = vol; nodeQueue = q
        if (!nodeWriter.running) nodeWriter.next()
    }

    function adjustNode(node, delta) {
        if (!node || !node.audio) return
        const base = nodeTargets[node.id] !== undefined ? nodeTargets[node.id] : node.audio.volume
        setNodeVolume(node, base + delta)
    }

    function toggleNodeMute(node) {
        if (node) Quickshell.execDetached(["wpctl", "set-mute", String(node.id), "toggle"])
    }

    Process {
        id: nodeWriter
        function next() {
            const ids = Object.keys(root.nodeQueue)
            if (!ids.length) {
                root.nodeTargets = ({})
                return
            }
            const id = ids[0]
            const q = Object.assign({}, root.nodeQueue)
            const vol = q[id]
            delete q[id]
            root.nodeQueue = q
            command = ["wpctl", "set-volume", id, vol.toFixed(4)]
            running = true
        }
        onExited: next()
    }

    // ---- pactl: card profiles, and which output each app plays to

    // [{name, description, objectId, active, address (bluetooth, else ""),
    //   profiles: [{name, description, codec, mode}]}]
    // A bluetooth card's codecs are its profiles: a2dp-sink-aac is music
    // over AAC, headset-head-unit is calls over mSBC; "codec X" in the
    // description names it (a2dp-sink is the best one, e.g. aptX HD).
    property var cards: []
    property var streamSinks: ({}) // app stream's node id -> {input: pulse index, sinkId: the sink's node id}

    function refreshExtras() {
        if (extrasProc.running) extrasPending = true
        else extrasProc.running = true
    }
    property bool extrasPending: false

    // the card behind a device node (sinks and sources carry the card's
    // pipewire object id as device.id)
    function cardFor(node) {
        if (!node || !node.properties) return null
        const dev = String(node.properties["device.id"] || "")
        return cards.find(c => c.objectId === dev) || null
    }

    function setProfile(card, profile) {
        Quickshell.execDetached(["pactl", "set-card-profile", card.name, profile])
        extrasLater.restart()
        // bluetooth renegotiates the codec for a second or two
        extrasSettle.restart()
    }

    // the card behind the default output (for its codec)
    function cardForSink() { return cardFor(Pipewire.defaultAudioSink) }

    // a bluetooth device's card, by its address (AA:BB:...)
    function cardForAddress(address) {
        return cards.find(c => c.address !== "" && c.address === address) || null
    }

    // A card's codecs for one mode ("music" or "call"), one per codec name:
    // where the best-codec profile (a2dp-sink) repeats a specific one, the
    // active one wins, else the specific one. [{codec, profile, active}]
    function codecs(card, mode) {
        if (!card) return []
        const out = []
        for (const p of card.profiles.filter(p => p.mode === mode && p.codec)) {
            const seen = out.find(o => o.codec === p.codec)
            const active = p.name === card.active
            if (!seen) out.push({ codec: p.codec, profile: p.name, active })
            else if (active) { seen.profile = p.name; seen.active = true }
        }
        return out
    }

    // what a card is using now: "aptX HD", "mSBC (call)", or "" (off)
    function activeCodec(card) {
        if (!card) return ""
        const p = card.profiles.find(p => p.name === card.active)
        if (!p || !p.codec) return ""
        return p.mode === "call" ? p.codec + " (call)" : p.codec
    }

    // the node id of the device an app is playing to, or -1
    function sinkOf(stream) {
        const s = streamSinks[String(stream.id)]
        return s ? s.sinkId : -1
    }

    function moveStream(stream, sink) {
        const s = streamSinks[String(stream.id)]
        if (!s || !sink) return
        Quickshell.execDetached(["pactl", "move-sink-input", String(s.input), sink.name])
        extrasLater.restart()
    }

    Timer { id: extrasLater; interval: 400; onTriggered: root.refreshExtras() }
    Timer { id: extrasSettle; interval: 2000; onTriggered: root.refreshExtras() }

    // a new app starting or a device appearing changes both lists
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { if (root.trackAll) extrasLater.restart() }
    }

    // a headset connecting or leaving brings or takes its card (and codecs)
    Connections {
        target: BluetoothState
        function onConnectedDevicesChanged() { extrasSettle.restart() }
    }

    // no read at startup: quick and sound read the cards when they open

    Process {
        id: extrasProc
        command: ["sh", "-c", "pactl -f json list cards; echo; echo '#'; pactl -f json list sink-inputs; echo; echo '#'; pactl -f json list sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n#\n")
                const parse = (s) => { try { return JSON.parse(s) } catch (e) { return [] } }
                const cards = parse(parts[0] || "[]")
                const inputs = parse(parts[1] || "[]")
                const sinks = parse(parts[2] || "[]")

                root.cards = cards.map(c => {
                    const props = c.properties || {}
                    const profiles = Object.keys(c.profiles || {})
                        .filter(k => c.profiles[k].available !== false)
                        .map(k => {
                            const description = c.profiles[k].description || k
                            const codec = (description.match(/codec ([^)]+)\)/) || [])[1] || ""
                            const mode = k.startsWith("a2dp") ? "music" : k.startsWith("headset") ? "call" : ""
                            return { name: k, description, codec: codec.replace(/^MSBC$/, "mSBC"), mode }
                        })
                    return {
                        name: c.name,
                        description: props["device.description"] || c.name,
                        objectId: String(props["object.id"] || ""),
                        address: props["api.bluez5.address"] || "",
                        active: c.active_profile || "",
                        profiles,
                    }
                })

                const sinkIds = {}
                for (const s of sinks) sinkIds[s.index] = parseInt((s.properties || {})["object.id"])
                const map = {}
                for (const i of inputs) {
                    const id = (i.properties || {})["object.id"]
                    if (id !== undefined) map[String(id)] = { input: i.index, sinkId: sinkIds[i.sink] !== undefined ? sinkIds[i.sink] : -1 }
                }
                root.streamSinks = map
            }
        }
        onExited: {
            if (root.extrasPending) {
                root.extrasPending = false
                running = true
            }
        }
    }
}
