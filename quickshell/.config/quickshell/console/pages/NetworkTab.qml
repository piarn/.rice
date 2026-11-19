// The console's network page. Opened from the top row's network, $mod+n, or
// `qs ipc call popup toggle network`. As readout rows:
//   RADIOS      wi-fi and airplane (every radio, bluetooth too), as lights;
//               `reload` re-reads NetworkManager's profiles, `settings` opens
//               nmtui for anything deeper (static IPs, DNS servers, certs, WEP)
//   INTERFACES  every managed ethernet/wifi/wwan device; the light is
//               connected (click connects/disconnects), › opens its details:
//               addresses, gateway, DNS, MAC, speed, the wi-fi channel and
//               rate, autoconnect (a light), the saved password (› shows),
//               make primary, copy ip/password
//   VPN         NetworkManager vpn/wireguard profiles and provider extras
//               (Mullvad, Tailscale, ...; components/VpnProvider.qml), lights
//   WI-FI       nearby networks: click connects (asks for a password first
//               when there's no saved profile; PEAP for 802.1X), saved ones
//               have › to forget; search for crowded places; `hidden` joins
//               one that doesn't broadcast
// Keys: w wi-fi · a airplane · r rescan · / search.
import QtQuick
import quickshell
import "../../state"
import "../../components"
import "../../island"

Tab {
    id: menu
    name: "network"

    property string lastAttempted: ""
    // Network whose credentials form is open: a wifiNetworks entry, or
    // {hidden: true} for `hidden`.
    property var pwNet: null
    readonly property bool credsOpen: pwNet !== null
    readonly property bool credsHidden: credsOpen && !!pwNet.hidden
    readonly property bool credsEnterprise: credsOpen && /802\.1X/.test(pwNet.security || "")
    // the keyboard goes to the text boxes while typing credentials or searching
    needsKeyboard: credsOpen || searching || ExtrasState.vpns.some(v => v.wantsKeyboard)
    property bool searching: false

    // what's open: a VPN provider's panel, a device's details, a saved
    // network's forget row
    property string openVpn: ""
    property string openDevice: ""
    property string openNet: ""

    hotkeys: ({
        "w": () => NetworkState.setWifiEnabled(!NetworkState.wifiEnabled),
        "a": () => NetworkState.toggleAirplane(),
        "r": () => NetworkState.scan(),
        "/": () => searchInput.forceActiveFocus(),
    })

    function toggleDevice(dev) {
        if (openDevice === dev.device) {
            openDevice = ""
            return
        }
        openDevice = dev.device
        NetworkState.loadDetails(dev)
    }

    // [label, value] pairs for an open device's details
    function detailLines(dev, info) {
        const lines = []
        if (info.ip4.length) lines.push(["ipv4", info.ip4.join(", ")])
        if (info.gateway) lines.push(["gateway", info.gateway])
        if (info.dns.length) lines.push(["dns", info.dns.join(", ")])
        if (info.ip6.length) lines.push(["ipv6", info.ip6[0] + (info.ip6.length > 1 ? " +" + (info.ip6.length - 1) : "")])
        if (info.wifi) {
            lines.push(["channel", ["ch " + info.wifi.channel, info.wifi.freq, info.wifi.rate].filter(s => s).join(" · ")])
            lines.push(["security", info.wifi.security])
            lines.push(["bssid", info.wifi.bssid])
        }
        if (info.speed) lines.push(["speed", info.speed])
        if (info.mac) lines.push(["mac", info.mac + (info.mtu ? " · mtu " + info.mtu : "")])
        if (dev.connection) lines.push(["profile", dev.connection])
        return lines
    }

    // passwords are only shown until the page closes
    onShownChanged: if (!shown) {
        openDevice = ""
        NetworkState.passwords = ({})
    }

    readonly property var vpnProviders: ExtrasState.vpns.filter(v => v.available)
    // A provider's own tunnel can surface as an NM connection (e.g.
    // wg0-mullvad) — it's already listed as the provider.
    readonly property var nmVpns: {
        const hidden = [].concat(...ExtrasState.vpns.map(v => Array.from(v.interfaces)))
        return NetworkState.vpns.filter(v => !hidden.some(h => v.name.startsWith(h)))
    }

    readonly property var shownNetworks: {
        if (!NetworkState.wifiEnabled) return []
        const words = searchInput.text.toLowerCase().split(/\s+/).filter(w => w)
        if (!words.length) return NetworkState.wifiNetworks
        return NetworkState.wifiNetworks.filter(n => {
            const ssid = n.ssid.toLowerCase()
            return words.every(w => ssid.includes(w))
        })
    }

    function stopSearch() {
        searching = false
        focusCatcher()
    }

    readonly property int routedCount: NetworkState.devices.filter(d => d.connected && d.gateway).length

    function clickNetwork(net) {
        if (net.active) return
        // WEP needs more than a password field.
        if (!net.known && /WEP/.test(net.security)) {
            NetworkState.openEditor()
            close()
            return
        }
        if (net.security && !net.known) {
            pwNet = net
            return
        }
        pwNet = null
        lastAttempted = net.ssid
        NetworkState.connectWifi(net)
    }

    function openHidden() {
        pwNet = { hidden: true, ssid: "", security: "" }
    }

    function submitCredentials() {
        if (!pwNet) return
        const password = pwField.text
        const identity = credsEnterprise ? userField.text.trim() : ""
        const net = credsHidden ? { hidden: true, ssid: ssidField.text.trim(), security: "" } : pwNet
        // hidden: SSID required, password optional (open network)
        if (!net.ssid || (credsEnterprise && !identity) || (!credsHidden && !password)) return
        lastAttempted = net.ssid
        pwNet = null
        NetworkState.connectWifi(net, password, identity)
    }

    function cancelPassword() {
        pwNet = null
        if (searching) searchInput.forceActiveFocus()
        else focusCatcher()
    }

    function deviceTitle(dev) {
        if (dev.type === "wifi") return dev.connection || "wi-fi"
        if (dev.type === "wwan") return dev.connection || "mobile"
        // netplan-generated profile names are just a uuid — not worth showing
        return dev.connection && !dev.connection.startsWith("netplan-") ? dev.connection : "ethernet"
    }

    function deviceDetail(dev) {
        if (dev.connected) {
            const parts = [dev.ip || "no ip"]
            if (dev.type === "wifi") parts.unshift(dev.signal + "%")
            if (dev.primary && menu.routedCount > 1) parts.push("primary")
            return parts.join(" · ")
        }
        if (dev.state === "unavailable") return dev.type === "ethernet" ? "cable unplugged" : "unavailable"
        return dev.state
    }

    onPwNetChanged: {
        ssidField.text = ""
        userField.text = ""
        pwField.text = ""
        if (!pwNet) return
        const first = credsHidden ? ssidField : credsEnterprise ? userField : pwField
        Qt.callLater(() => first.input.forceActiveFocus())
    }

    function reloadAll() {
        NetworkState.reloadConnections()
        NetworkState.scan()
        for (const v of ExtrasState.vpns) { v.actionStatus = ""; v.refresh() }
    }

    onOpened: {
        pwNet = null
        searching = false
        searchInput.text = ""
        openNet = ""
        NetworkState.actionStatus = ""
        NetworkState.refresh()
        NetworkState.scan()
        for (const v of ExtrasState.vpns) { v.actionStatus = ""; v.refresh() }
    }

    // A failed connect to a secured network most often means a wrong or
    // missing password — reopen the password row for it.
    Connections {
        target: NetworkState
        function onActionStatusChanged() {
            if (NetworkState.actionStatus.startsWith("failed") && menu.lastAttempted) {
                const net = NetworkState.wifiNetworks.find(n => n.ssid === menu.lastAttempted)
                if (net && net.security && !/WEP/.test(net.security)) menu.pwNet = net
                menu.lastAttempted = ""
            } else if (NetworkState.actionStatus === "") {
                menu.lastAttempted = ""
            }
        }
    }

    // ---- RADIOS
    SectionHeader {
        title: "radios"
        topGap: 0

        TextButton {
            label: "reload"
            baseColor: Colors.gray2
            enabled: !NetworkState.busy
            onClicked: menu.reloadAll()
        }
        TextButton {
            label: "settings"
            baseColor: Colors.gray2
            onClicked: {
                NetworkState.openEditor()
                menu.close()
            }
        }
    }

    ReadoutRow {
        id: wifiRadio
        label: "wi-fi"
        value: NetworkState.wifiEnabled ? "on" : "off"
        valueColor: NetworkState.wifiEnabled ? Colors.fg : Colors.gray2
        light: NetworkState.wifiEnabled
        key: "w"
        dim: NetworkState.busy
        selected: menu.selectedRow === wifiRadio
        onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
    }
    ReadoutRow {
        id: airRadio
        label: "airplane"
        value: NetworkState.airplane ? "every radio off" : "off"
        valueColor: NetworkState.airplane ? Colors.amber : Colors.gray2
        light: NetworkState.airplane
        key: "a"
        dim: NetworkState.busy
        selected: menu.selectedRow === airRadio
        onToggled: NetworkState.toggleAirplane()
    }

    // ---- INTERFACES
    SectionHeader {
        title: "interfaces"
        count: String(NetworkState.devices.length)
    }

    MonoText {
        visible: NetworkState.devices.length === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "no network devices"
    }

    Repeater {
        model: NetworkState.devices

        delegate: Column {
            id: devItem
            required property var modelData
            readonly property var dev: modelData
            readonly property bool open: menu.openDevice === dev.device
            readonly property var info: NetworkState.details[dev.device] || null
            readonly property bool hasPassword: dev.uuid !== "" && NetworkState.passwords[dev.uuid] !== undefined
            width: menu.innerWidth
            spacing: 0

            ReadoutRow {
                id: devRow
                label: menu.deviceTitle(devItem.dev) + "  " + devItem.dev.device
                labelColor: devItem.dev.connected ? Colors.fg : Colors.gray2
                value: menu.deviceDetail(devItem.dev)
                valueColor: devItem.dev.connected ? Colors.gray2 : Colors.gray
                light: devItem.dev.state !== "unavailable" ? devItem.dev.connected : undefined
                opens: true
                selected: menu.selectedRow === devRow
                onToggled: if (!NetworkState.busy) NetworkState.toggleDevice(devItem.dev)
                onOpened: menu.toggleDevice(devItem.dev)
            }

            // details, loaded when opened
            Column {
                visible: devItem.open
                width: parent.width
                spacing: 0

                ReadoutRow {
                    visible: devItem.info === null
                    indent: 30
                    label: "loading…"
                    dim: true
                }

                Repeater {
                    model: devItem.info ? menu.detailLines(devItem.dev, devItem.info) : []
                    delegate: ReadoutRow {
                        required property var modelData
                        indent: 30
                        label: modelData[0]
                        value: modelData[1]
                        valueColor: Colors.gray2
                    }
                }

                ReadoutRow {
                    id: autoRow
                    visible: devItem.dev.uuid !== "" && devItem.info !== null
                    indent: 30
                    label: "autoconnect"
                    value: devItem.info && devItem.info.autoconnect ? "on" : "off"
                    valueColor: Colors.gray2
                    light: devItem.info !== null && devItem.info.autoconnect
                    selected: menu.selectedRow === autoRow
                    onToggled: if (!NetworkState.busy) NetworkState.setAutoconnect(devItem.dev, !devItem.info.autoconnect)
                }
                ReadoutRow {
                    id: pwRow
                    visible: devItem.dev.type === "wifi" && devItem.dev.uuid !== ""
                    indent: 30
                    label: "password"
                    value: devItem.hasPassword ? NetworkState.passwords[devItem.dev.uuid] : "hidden"
                    valueColor: devItem.hasPassword ? Colors.amber : Colors.gray
                    opens: true
                    selected: menu.selectedRow === pwRow
                    onOpened: devItem.hasPassword ? NetworkState.hidePassword(devItem.dev) : NetworkState.revealPassword(devItem.dev)
                }

                Flow {
                    width: parent.width
                    leftPadding: Style.inset + 30
                    rightPadding: Style.inset
                    topPadding: 4
                    bottomPadding: 4
                    spacing: 6

                    TextButton {
                        visible: devItem.dev.connected && !devItem.dev.primary && devItem.dev.gateway !== ""
                        label: "make primary"
                        enabled: !NetworkState.busy
                        onClicked: NetworkState.setPrimary(devItem.dev)
                    }
                    TextButton {
                        visible: devItem.info !== null && devItem.info.ip4.length > 0
                        label: "copy ip"
                        baseColor: Colors.gray2
                        onClicked: NetworkState.copy(devItem.info.ip4[0].split("/")[0])
                    }
                    TextButton {
                        visible: devItem.dev.type === "wifi" && !!NetworkState.passwords[devItem.dev.uuid]
                        label: "copy password"
                        baseColor: Colors.gray2
                        onClicked: NetworkState.copy(NetworkState.passwords[devItem.dev.uuid])
                    }
                }
            }
        }
    }

    // ---- VPN
    SectionHeader {
        visible: menu.nmVpns.length > 0 || menu.vpnProviders.length > 0
        title: "vpn"
    }

    Repeater {
        model: menu.nmVpns

        delegate: ReadoutRow {
            id: vpnRow
            required property var modelData
            label: modelData.name
            labelColor: modelData.active ? Colors.fg : Colors.gray2
            value: modelData.active ? "connected · " + modelData.type : modelData.type
            valueColor: Colors.gray2
            light: modelData.active
            dim: NetworkState.busy
            selected: menu.selectedRow === vpnRow
            onToggled: NetworkState.toggleVpn(vpnRow.modelData)
        }
    }

    // VPN provider extras (components/VpnProvider): the light connects; ›
    // expands their own panel when they have one.
    Repeater {
        model: menu.vpnProviders

        delegate: Column {
            id: provRow
            required property var modelData
            readonly property var vpn: modelData
            readonly property bool expanded: menu.openVpn === vpn.name
            width: menu.innerWidth
            spacing: 0

            ReadoutRow {
                id: provLine
                label: provRow.vpn.name
                labelColor: provRow.vpn.active ? Colors.fg : Colors.gray2
                value: [provRow.vpn.status, provRow.vpn.detail].filter(s => s).join(" · ")
                valueColor: provRow.vpn.busy || provRow.vpn.warning ? Colors.amber : Colors.gray2
                light: provRow.vpn.canToggle ? (provRow.vpn.active || provRow.vpn.busy) : undefined
                opens: provRow.vpn.detailComponent.toString() !== ""
                dim: provRow.vpn.running
                selected: menu.selectedRow === provLine
                onToggled: provRow.vpn.toggle()
                onOpened: menu.openVpn = provRow.expanded ? "" : provRow.vpn.name
            }
            MonoText {
                width: parent.width
                visible: text !== ""
                leftPadding: Style.inset + 30
                rightPadding: Style.inset
                wrapMode: Text.Wrap
                color: provRow.vpn.actionStatus.startsWith("failed") ? Colors.red : Colors.gray2
                text: provRow.vpn.actionStatus
            }
            Loader {
                active: provRow.expanded
                visible: active
                width: parent.width
                // loads on first expand, keeping `provider` for it
                Component.onCompleted: setSource(provRow.vpn.detailComponent, { provider: provRow.vpn })
            }
        }
    }

    // ---- WI-FI
    SectionHeader {
        visible: NetworkState.wifiDevice !== null
        title: !NetworkState.wifiEnabled ? "wi-fi · off" : NetworkState.scanning ? "wi-fi · scanning" : "wi-fi"
        count: NetworkState.wifiEnabled && !NetworkState.scanning ? String(NetworkState.wifiNetworks.length) : ""

        TextButton {
            visible: NetworkState.wifiEnabled
            label: "hidden"
            baseColor: Colors.gray2
            onClicked: menu.openHidden()
        }
        TextButton {
            visible: NetworkState.wifiEnabled
            label: "rescan  r"
            baseColor: Colors.gray2
            enabled: !NetworkState.scanning
            onClicked: NetworkState.scan()
        }
    }

    // Search, for places with a lot of networks (offices broadcast hundreds):
    // space-separated words, all must appear in the SSID. `/` focuses it.
    Item {
        visible: NetworkState.wifiDevice !== null && NetworkState.wifiEnabled
        width: parent.width
        height: Style.rowHeight + 2

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Style.inset
            anchors.rightMargin: Style.inset
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            radius: Style.round
            color: Style.tint(Colors.fg, 0.04)
            border.color: searchInput.activeFocus ? Colors.neon : "transparent"
            border.width: 1

            MonoText {
                id: searchPrompt
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.gray
                text: "/"
            }

            TextInput {
                id: searchInput
                anchors.left: searchPrompt.right
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.family: Style.font
                font.pixelSize: Style.fontSize
                renderType: Text.NativeRendering
                color: Colors.fg
                clip: true
                onActiveFocusChanged: if (activeFocus) menu.searching = true
                onTextChanged: netList.keptY = 0
                Keys.onEscapePressed: {
                    if (text !== "") text = ""
                    else menu.stopSearch()
                }
                // Enter picks the top match.
                Keys.onReturnPressed: if (menu.shownNetworks.length) menu.clickNetwork(menu.shownNetworks[0])
                Keys.onEnterPressed: if (menu.shownNetworks.length) menu.clickNetwork(menu.shownNetworks[0])
            }

            MonoText {
                anchors.left: searchInput.left
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text === ""
                color: Colors.dim
                text: "search " + NetworkState.wifiNetworks.length + " networks"
            }
        }
    }

    MonoText {
        visible: NetworkState.wifiEnabled && searchInput.text !== "" && menu.shownNetworks.length === 0
        leftPadding: Style.inset
        color: Colors.gray
        text: "no networks match"
    }

    // ListView rather than a Repeater: with hundreds of networks only the
    // visible rows get built. Scrolls past 14 rows.
    ListView {
        id: netList
        width: parent.width
        height: Math.min(contentHeight, 14 * Style.rowHeight)
        visible: count > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: menu.shownNetworks

        // A new model (every poll where anything changed) jumps a ListView
        // back to the top; keep the scroll position instead.
        property real keptY: 0
        onContentYChanged: if (moving || dragging) keptY = contentY
        onMovementEnded: keptY = contentY
        onModelChanged: Qt.callLater(() => { netList.contentY = Math.min(netList.keptY, Math.max(0, netList.contentHeight - netList.height)) })

        delegate: Column {
            id: netItem
            required property var modelData
            readonly property bool forgetOpen: menu.openNet === modelData.ssid
            width: ListView.view.width

            ReadoutRow {
                id: netRow
                label: netItem.modelData.ssid
                labelColor: netItem.modelData.active ? Colors.fg : Colors.gray2
                value: [netItem.modelData.known ? "saved" : "", netItem.modelData.security ? "locked" : "open",
                        netItem.modelData.signal + "%"].filter(s => s).join(" · ")
                valueColor: netItem.modelData.active ? Colors.fg : Colors.gray
                // the connected one carries the light; clicking it does nothing
                light: netItem.modelData.active ? true : undefined
                // a click connects; a saved network's › opens its forget row
                opens: netItem.modelData.known
                splitChevron: true
                selected: menu.selectedRow === netRow
                onToggled: {}
                onOpened: menu.clickNetwork(netItem.modelData)
                onChevronClicked: menu.openNet = netItem.forgetOpen ? "" : netItem.modelData.ssid
            }
            Item {
                visible: netItem.forgetOpen
                width: parent.width
                height: Style.rowHeight
                TextButton {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.inset + 30
                    anchors.verticalCenter: parent.verticalCenter
                    label: "forget " + netItem.modelData.ssid
                    baseColor: Colors.red
                    enabled: !NetworkState.busy
                    onClicked: {
                        menu.openNet = ""
                        NetworkState.forgetWifi(netItem.modelData.ssid)
                    }
                }
            }
        }

        Rectangle {
            visible: netList.interactive
            parent: netList
            x: netList.width - width
            y: netList.visibleArea.yPosition * netList.height
            width: 2
            height: netList.visibleArea.heightRatio * netList.height
            color: Colors.surface
        }
    }

    // Outside the list on purpose: wifiNetworks is replaced on every
    // refresh, which rebuilds the delegates and would wipe a half-typed
    // password (and its focus) if the input lived there.
    Column {
        visible: menu.credsOpen
        width: parent.width
        leftPadding: Style.inset
        topPadding: 6
        spacing: 6

        MonoText {
            color: Colors.gray2
            text: menu.credsHidden ? "join a hidden network (no password = open)"
                : menu.credsEnterprise ? "sign in to " + (menu.pwNet ? menu.pwNet.ssid : "") + " (PEAP)"
                : "password for " + (menu.pwNet ? menu.pwNet.ssid : "")
        }

        InputField {
            id: ssidField
            visible: menu.credsHidden
            placeholder: "network name (SSID)"
            input.KeyNavigation.tab: pwField.input
            onAccepted: menu.submitCredentials()
            onEscaped: menu.cancelPassword()
        }
        InputField {
            id: userField
            visible: menu.credsEnterprise
            placeholder: "username"
            input.KeyNavigation.tab: pwField.input
            onAccepted: menu.submitCredentials()
            onEscaped: menu.cancelPassword()
        }

        Row {
            spacing: 8

            InputField {
                id: pwField
                placeholder: "password"
                password: true
                onAccepted: menu.submitCredentials()
                onEscaped: menu.cancelPassword()
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "connect"
                onClicked: menu.submitCredentials()
            }
            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "cancel"
                baseColor: Colors.gray2
                onClicked: menu.cancelPassword()
            }
        }
    }

    MonoText {
        width: parent.width
        visible: NetworkState.actionStatus !== ""
        leftPadding: Style.inset
        rightPadding: Style.inset
        topPadding: 4
        color: NetworkState.actionStatus.startsWith("failed") || NetworkState.actionStatus.startsWith("busy")
            ? Colors.red : Colors.gray2
        text: NetworkState.actionStatus
        wrapMode: Text.Wrap
    }
}
