// The control panel's network tab, opened from the strip's network icon,
// the quick tab's wi-fi tile, $mod+n or `qs ipc call popup toggle network`.
// The header switches wi-fi and airplane mode (every radio, bluetooth too);
// [reload] re-reads NetworkManager's profiles from disk and refreshes
// everything below. Sections:
//  - interfaces: every managed ethernet/wifi/wwan device, with the one
//    holding the default route marked primary. Click a device for its
//    details — addresses, gateway, DNS, MAC, link speed, the wi-fi channel
//    and rate — and its actions: [make primary], autoconnect on/off, and
//    for wi-fi the saved password ([show], [copy]).
//  - vpn: NetworkManager vpn/wireguard profiles, plus any VPN provider
//    extras (Mullvad, Tailscale, ...; see components/VpnProvider.qml) whose
//    client is installed. Hidden when there are none
//  - wi-fi: nearby networks, click to connect; asks for a password up front
//    for secured networks with no saved profile instead of failing first
// Enterprise (802.1X) networks take a username + password (PEAP/MSCHAPv2),
// and [hidden] joins a network that doesn't broadcast its SSID. Anything
// deeper (static IPs, DNS servers, certificates, WEP) goes to [settings],
// which opens nmtui in foot.
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
    // {hidden: true} for [hidden].
    property var pwNet: null
    readonly property bool credsOpen: pwNet !== null
    readonly property bool credsHidden: credsOpen && !!pwNet.hidden
    readonly property bool credsEnterprise: credsOpen && /802\.1X/.test(pwNet.security || "")
    // exclusive keyboard while typing credentials or searching (island/Island.qml)
    needsKeyboard: credsOpen || searching || ExtrasState.vpns.some(v => v.wantsKeyboard)
    property bool searching: false

    // Provider whose detail panel is expanded in the vpn section.
    property string openVpn: ""

    // the device (name) whose details are open
    property string openDevice: ""

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
        if (info.ip6.length) lines.push(["ipv6", info.ip6.join(", ")])
        if (info.wifi) {
            lines.push(["wi-fi", ["ch " + info.wifi.channel, info.wifi.freq, info.wifi.rate].filter(s => s).join(" · ")])
            lines.push(["security", info.wifi.security])
            lines.push(["bssid", info.wifi.bssid])
        }
        if (info.speed) lines.push(["speed", info.speed])
        if (info.mac) lines.push(["mac", info.mac + (info.mtu ? " · mtu " + info.mtu : "")])
        if (dev.connection) lines.push(["profile", dev.connection])
        return lines
    }

    // passwords are only shown until the panel closes
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
        if (dev.type === "wifi") return dev.connection || "Wi-Fi"
        if (dev.type === "wwan") return dev.connection || "Mobile"
        // netplan-generated profile names are just a uuid — not worth showing
        return dev.connection && !dev.connection.startsWith("netplan-") ? dev.connection : "Ethernet"
    }

    function deviceDetail(dev) {
        if (dev.connected) {
            const parts = [dev.ip || "no ip"]
            if (dev.type === "wifi") parts.unshift(dev.signal + "%")
            if (dev.gateway) parts.push("via " + dev.gateway, "metric " + dev.metric)
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

    // header
    Item {
        width: parent.width
        height: settingsBtn.implicitHeight

        MonoText {
            anchors.left: parent.left
            anchors.leftMargin: Style.inset
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.gray
            text: "interfaces"
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.inset
            spacing: 8

            TextButton {
                label: NetworkState.wifiEnabled ? "wi-fi off" : "wi-fi on"
                visible: NetworkState.wifiDevice !== null || !NetworkState.wifiEnabled
                baseColor: NetworkState.wifiEnabled ? Colors.acid : Colors.red
                enabled: !NetworkState.busy
                onClicked: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
            }
            TextButton {
                label: NetworkState.airplane ? "airplane off" : "airplane"
                baseColor: NetworkState.airplane ? Colors.amber : Colors.gray2
                enabled: !NetworkState.busy
                onClicked: NetworkState.toggleAirplane()
            }
            TextButton {
                label: "reload"
                enabled: !NetworkState.busy
                onClicked: menu.reloadAll()
            }
            TextButton {
                id: settingsBtn
                label: "settings"
                onClicked: {
                    NetworkState.openEditor()
                    menu.close()
                }
            }
        }
    }

    // interfaces
    Column {
        width: parent.width
        spacing: 4

        MonoText {
            visible: NetworkState.devices.length === 0
            color: Colors.gray
            text: "no network devices"
        }

        Repeater {
            model: NetworkState.devices

            delegate: Column {
                id: devItem
                required property var modelData
                readonly property bool open: menu.openDevice === modelData.device
                readonly property var info: NetworkState.details[modelData.device] || null
                width: menu.innerWidth
                spacing: 4

            Rectangle {
                id: devRow
                readonly property var modelData: devItem.modelData
                readonly property bool usable: modelData.state !== "unavailable"
                width: menu.innerWidth
                height: devCol.implicitHeight + 10
                radius: Style.round
                color: devMouse.containsMouse ? Style.tint(Colors.fg, 0.07) : modelData.connected ? Style.tint(Colors.fg, 0.04) : "transparent"

                Marker { visible: devRow.modelData.primary }

                // the row opens its details; the buttons on it still act
                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.toggleDevice(devItem.modelData)
                }

                Icon {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    font.pixelSize: 16
                    color: !devRow.modelData.connected ? Colors.gray
                        : devRow.modelData.primary ? Colors.neon : Colors.gray2
                    text: NetworkState.icon(devRow.modelData)
                }

                Column {
                    id: devCol
                    anchors.left: devIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Item {
                        width: parent.width
                        height: devTitle.implicitHeight

                        MonoText {
                            id: devTitle
                            anchors.left: parent.left
                            width: Math.min(implicitWidth, parent.width - devName.implicitWidth - devActions.implicitWidth - 16)
                            font.pixelSize: Style.fontSize
                            elide: Text.ElideRight
                            color: devRow.modelData.connected ? Colors.fg : Colors.gray2
                            text: menu.deviceTitle(devRow.modelData)
                        }
                        MonoText {
                            id: devName
                            anchors.left: devTitle.right
                            anchors.leftMargin: 6
                            anchors.baseline: devTitle.baseline
                            font.pixelSize: 11
                            color: Colors.gray
                            text: devRow.modelData.device
                        }

                        Row {
                            id: devActions
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            MonoText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: devRow.modelData.primary && menu.routedCount > 1
                                font.pixelSize: 11
                                color: Colors.neon
                                text: "\u2605 primary"
                            }
                            TextButton {
                                visible: devRow.usable
                                label: devRow.modelData.connected ? "disconnect" : "connect"
                                baseColor: devRow.modelData.connected ? Colors.gray2 : Colors.acid
                                enabled: !NetworkState.busy
                                onClicked: NetworkState.toggleDevice(devRow.modelData)
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                color: Colors.gray2
                                text: devItem.open ? "\u{e5ce}" : "\u{e5cf}"   // expand_less / expand_more
                            }
                        }
                    }

                    MonoText {
                        width: parent.width
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: devRow.modelData.connected ? Colors.gray2 : Colors.gray
                        text: menu.deviceDetail(devRow.modelData)
                    }
                }
            }

            // details, loaded when opened
            Column {
                visible: devItem.open
                width: parent.width
                leftPadding: 34
                spacing: 3

                MonoText {
                    visible: devItem.info === null
                    font.pixelSize: 11
                    color: Colors.gray
                    text: "loading…"
                }

                Repeater {
                    model: devItem.info ? menu.detailLines(devItem.modelData, devItem.info) : []

                    delegate: Row {
                        required property var modelData
                        spacing: 8

                        MonoText {
                            width: 64
                            font.pixelSize: 11
                            color: Colors.gray
                            text: modelData[0]
                        }
                        MonoText {
                            width: menu.innerWidth - 34 - 72
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                            color: Colors.fg
                            text: modelData[1]
                        }
                    }
                }

                // the saved wi-fi password, once asked for
                Row {
                    visible: devItem.modelData.uuid !== "" && NetworkState.passwords[devItem.modelData.uuid] !== undefined
                    spacing: 8

                    MonoText {
                        width: 64
                        font.pixelSize: 11
                        color: Colors.gray
                        text: "password"
                    }
                    MonoText {
                        font.pixelSize: 11
                        color: Colors.amber
                        text: NetworkState.passwords[devItem.modelData.uuid] || ""
                    }
                }

                Flow {
                    width: parent.width - parent.leftPadding
                    spacing: 12
                    topPadding: 2

                    TextButton {
                        visible: devItem.modelData.connected && !devItem.modelData.primary && devItem.modelData.gateway !== ""
                        label: "make primary"
                        enabled: !NetworkState.busy
                        onClicked: NetworkState.setPrimary(devItem.modelData)
                    }
                    TextButton {
                        visible: devItem.modelData.uuid !== "" && devItem.info !== null
                        label: devItem.info && devItem.info.autoconnect ? "autoconnect on" : "autoconnect off"
                        baseColor: devItem.info && devItem.info.autoconnect ? Colors.acid : Colors.gray2
                        enabled: !NetworkState.busy
                        onClicked: NetworkState.setAutoconnect(devItem.modelData, !devItem.info.autoconnect)
                    }
                    TextButton {
                        readonly property bool shown: NetworkState.passwords[devItem.modelData.uuid] !== undefined
                        visible: devItem.modelData.type === "wifi" && devItem.modelData.uuid !== ""
                        label: shown ? "hide password" : "show password"
                        baseColor: Colors.gray2
                        onClicked: shown ? NetworkState.hidePassword(devItem.modelData) : NetworkState.revealPassword(devItem.modelData)
                    }
                    TextButton {
                        visible: devItem.modelData.type === "wifi" && !!NetworkState.passwords[devItem.modelData.uuid]
                        label: "copy password"
                        baseColor: Colors.gray2
                        onClicked: NetworkState.copy(NetworkState.passwords[devItem.modelData.uuid])
                    }
                    TextButton {
                        visible: devItem.info !== null && devItem.info.ip4.length > 0
                        label: "copy ip"
                        baseColor: Colors.gray2
                        onClicked: NetworkState.copy(devItem.info.ip4[0].split("/")[0])
                    }
                }
            }
            }
        }
    }

    // vpn
    Rectangle { width: parent.width; height: 1; color: Colors.surface; visible: vpnCol.visible }

    Column {
        id: vpnCol
        width: parent.width
        spacing: 4
        visible: menu.nmVpns.length > 0 || menu.vpnProviders.length > 0

        MonoText {
            leftPadding: Style.inset
            color: Colors.gray
            text: "vpn"
        }

        Repeater {
            model: menu.nmVpns

            delegate: Item {
                id: vpnRow
                required property var modelData
                width: menu.innerWidth
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.right: vpnBtn.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Icon {
                        color: vpnRow.modelData.active ? Colors.neon : Colors.gray
                        text: "\u{e62f}"   // vpn_lock
                    }
                    MonoText {
                        width: parent.width - 30
                        font.pixelSize: Style.fontSize
                        elide: Text.ElideRight
                        color: vpnRow.modelData.active ? Colors.fg : Colors.gray2
                        text: vpnRow.modelData.name + "  " + vpnRow.modelData.type
                    }
                }

                TextButton {
                    id: vpnBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    label: vpnRow.modelData.active ? "disconnect" : "connect"
                    baseColor: vpnRow.modelData.active ? Colors.gray2 : Colors.acid
                    enabled: !NetworkState.busy
                    onClicked: NetworkState.toggleVpn(vpnRow.modelData)
                }
            }
        }

        // VPN provider extras (components/VpnProvider): name + status on
        // top, their one-line detail below, › expands their own panel.
        Repeater {
            model: menu.vpnProviders

            delegate: Column {
                id: provRow
                required property var modelData
                readonly property var vpn: modelData
                readonly property bool expanded: menu.openVpn === vpn.name
                width: menu.innerWidth
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: provCol.implicitHeight + 10
                    radius: Style.round
                    color: provRow.vpn.active ? Style.tint(Colors.fg, 0.04) : "transparent"

                    Icon {
                        id: provIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        color: provRow.vpn.busy || provRow.vpn.warning ? Colors.amber
                            : provRow.vpn.active ? Colors.neon : Colors.gray
                        text: "\u{e62f}"   // vpn_lock
                    }

                    Column {
                        id: provCol
                        anchors.left: provIcon.right
                        anchors.right: provActions.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Row {
                            spacing: 6
                            MonoText {
                                id: provName
                                font.pixelSize: Style.fontSize
                                color: provRow.vpn.active ? Colors.fg : Colors.gray2
                                text: provRow.vpn.name
                            }
                            MonoText {
                                anchors.baseline: provName.baseline
                                font.pixelSize: 11
                                color: provRow.vpn.busy || provRow.vpn.warning ? Colors.amber
                                    : provRow.vpn.active ? Colors.fg : Colors.gray
                                text: provRow.vpn.status
                            }
                        }
                        MonoText {
                            width: parent.width
                            visible: text !== ""
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            color: Colors.gray2
                            text: provRow.vpn.detail
                        }
                        MonoText {
                            width: parent.width
                            visible: text !== ""
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            color: provRow.vpn.actionStatus.startsWith("failed") ? Colors.red : Colors.gray2
                            text: provRow.vpn.actionStatus
                        }
                    }

                    Row {
                        id: provActions
                        anchors.right: parent.right
                        anchors.rightMargin: Style.inset
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        TextButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: provRow.vpn.canToggle
                            label: provRow.vpn.active || provRow.vpn.busy ? "disconnect" : "connect"
                            baseColor: provRow.vpn.active ? Colors.gray2 : Colors.acid
                            enabled: !provRow.vpn.running
                            onClicked: provRow.vpn.toggle()
                        }

                        Rectangle {
                            visible: provRow.vpn.detailComponent.toString() !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            color: chevMouse.containsMouse ? Style.tint(Colors.fg, 0.08) : "transparent"

                            Icon {
                                anchors.centerIn: parent
                                color: Colors.gray2
                                text: provRow.expanded ? "\u{e5ce}" : "\u{e5cf}"   // expand_less / expand_more
                            }
                            MouseArea {
                                id: chevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: menu.openVpn = provRow.expanded ? "" : provRow.vpn.name
                            }
                        }
                    }
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
    }

    // wi-fi
    Rectangle { width: parent.width; height: 1; color: Colors.surface; visible: wifiCol.visible }

    Column {
        id: wifiCol
        width: parent.width
        spacing: 2
        visible: NetworkState.wifiDevice !== null

        Item {
            width: parent.width
            height: rescanBtn.implicitHeight + 4

            MonoText {
                anchors.left: parent.left
                anchors.leftMargin: Style.inset
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.gray
                text: !NetworkState.wifiEnabled ? "wi-fi is off"
                    : NetworkState.scanning ? "wi-fi · scanning…" : "wi-fi networks"
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Style.inset
                spacing: 8
                visible: NetworkState.wifiEnabled

                TextButton {
                    label: "hidden"
                    baseColor: Colors.gray2
                    onClicked: menu.openHidden()
                }
                TextButton {
                    id: rescanBtn
                    label: "rescan"
                    enabled: !NetworkState.scanning
                    onClicked: NetworkState.scan()
                }
            }
        }

        // Search, for places with a lot of networks (offices broadcast
        // hundreds): space-separated words, all must appear in the SSID.
        Rectangle {
            width: parent.width
            height: 28
            radius: Style.round
            visible: NetworkState.wifiEnabled
            color: Style.tint(Colors.fg, 0.05)
            border.color: searchInput.activeFocus ? Colors.neon : "transparent"
            border.width: 1

            Icon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12
                color: Colors.gray
                text: "\u{ef7a}"   // search
            }

            TextInput {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.right: clearSearch.left
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                font.family: Style.font
                font.pixelSize: Style.fontSize
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
                color: Colors.gray
                text: "search " + NetworkState.wifiNetworks.length + " networks"
            }

            Icon {
                id: clearSearch
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text !== ""
                width: visible ? implicitWidth : 0
                font.pixelSize: 12
                color: clearMouse.containsMouse ? Colors.fg : Colors.gray
                text: "\u{e5cd}"   // close

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: searchInput.text = ""
                }
            }
        }

        MonoText {
            visible: NetworkState.wifiEnabled && searchInput.text !== "" && menu.shownNetworks.length === 0
            leftPadding: 8
            color: Colors.gray
            text: "no networks match"
        }

        // ListView rather than a Repeater: with hundreds of networks only
        // the visible rows get built. Scrolls past 8 rows (28px + 2px
        // spacing) so the popup never runs off the screen.
        ListView {
            id: netList
            width: parent.width
            height: Math.min(contentHeight, 14 * 30)
            visible: count > 0
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            model: menu.shownNetworks

            // A new model (every poll where anything changed) jumps a
            // ListView back to the top; keep the scroll position instead.
            property real keptY: 0
            onContentYChanged: if (moving || dragging) keptY = contentY
            onMovementEnded: keptY = contentY
            onModelChanged: Qt.callLater(() => { netList.contentY = Math.min(netList.keptY, Math.max(0, netList.contentHeight - netList.height)) })

            delegate: Rectangle {
                id: netRow
                required property var modelData
                width: ListView.view.width
                height: 28
                radius: Style.round
                color: netMouse.containsMouse ? Style.tint(Colors.fg, 0.05) : "transparent"

                Marker { visible: netRow.modelData.active }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: netRow.modelData.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: menu.clickNetwork(netRow.modelData)
                }

                Icon {
                    id: netIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    color: netRow.modelData.active ? Colors.neon : Colors.gray2
                    text: NetworkState.wifiGlyph(netRow.modelData.signal)
                }

                MonoText {
                    anchors.left: netIcon.right
                    anchors.right: netRight.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Style.fontSize
                    elide: Text.ElideRight
                    color: netRow.modelData.active ? Colors.fg : Colors.gray2
                    text: netRow.modelData.ssid
                }

                Row {
                    id: netRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // only saved networks have something to forget,
                    // so this doubles as the "saved" marker
                    TextButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: netRow.modelData.known
                        label: "forget"
                        baseColor: Colors.gray
                        enabled: !NetworkState.busy
                        onClicked: NetworkState.forgetWifi(netRow.modelData.ssid)
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        color: Colors.gray2
                        text: netRow.modelData.security ? "\u{e899}" : ""   // lock
                    }
                    MonoText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: 11
                        color: Colors.gray2
                        text: netRow.modelData.signal + "%"
                    }
                }
            }

            Rectangle {
                visible: netList.interactive
                parent: netList
                x: netList.width - width
                y: netList.visibleArea.yPosition * netList.height
                width: 3
                height: netList.visibleArea.heightRatio * netList.height
                color: Colors.gray
            }
        }

        // Outside the Repeater on purpose: wifiNetworks is replaced on
        // every refresh, which rebuilds the delegates and would wipe a
        // half-typed password (and its focus) if the input lived there.
        Column {
            visible: menu.credsOpen
            width: parent.width
            leftPadding: 8
            topPadding: 4
            spacing: 6

            MonoText {
                font.pixelSize: 11
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
    }

    MonoText {
        width: parent.width
        visible: NetworkState.actionStatus !== ""
        color: NetworkState.actionStatus.startsWith("failed") || NetworkState.actionStatus.startsWith("busy")
            ? Colors.red : Colors.acid
        text: NetworkState.actionStatus
        wrapMode: Text.Wrap
    }
}
