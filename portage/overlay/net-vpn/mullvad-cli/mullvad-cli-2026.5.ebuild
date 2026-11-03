# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

# Mullvad's daemon and command-line client from its official RPM, without the
# Electron app. guru's net-vpn/mullvadvpn-app installs the same RPM whole: about
# 360 MB of app, with CUPS, GTK and X11 libraries as dependencies.

EAPI=8

RPM_COMPRESS_TYPE="xz"
inherit rpm systemd shell-completion

DESCRIPTION="Mullvad VPN daemon and CLI, without the app"
HOMEPAGE="https://github.com/mullvad/mullvadvpn-app https://mullvad.net/"
SRC_URI="https://github.com/mullvad/mullvadvpn-app/releases/download/${PV}/MullvadVPN-${PV}_x86_64.rpm"
S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

RDEPEND="
	sys-apps/dbus
	|| (
		net-firewall/nftables
		net-firewall/iptables[nftables]
	)
	!net-vpn/mullvadvpn-app
"

QA_PREBUILT="*"

src_install() {
	local res="/opt/Mullvad VPN/resources"

	dobin usr/bin/mullvad usr/bin/mullvad-daemon usr/bin/mullvad-exclude
	# lets a user exclude their own programs from the tunnel (cgroups need root)
	fperms 4755 /usr/bin/mullvad-exclude

	# The daemon's unit sets MULLVAD_RESOURCE_DIR to this; it reads the root CA
	# and the bundled relay list there. Everything else in it is the app.
	insinto "${res}"
	doins ".${res}/ca.crt" ".${res}/relays.json"
	exeinto "${res}"
	doexe ".${res}/mullvad-setup" ".${res}/mullvad-problem-report"
	dosym -r "${res}/mullvad-problem-report" /usr/bin/mullvad-problem-report

	systemd_newunit usr/lib/systemd/system/mullvad-daemon.service mullvad-daemon.service
	systemd_newunit usr/lib/systemd/system/mullvad-early-boot-blocking.service mullvad-early-boot-blocking.service

	newbashcomp usr/share/bash-completion/completions/mullvad mullvad
	newzshcomp usr/share/zsh/site-functions/_mullvad _mullvad
}

pkg_postinst() {
	[[ -n ${REPLACING_VERSIONS} ]] && elog "Restart the daemon: systemctl restart mullvad-daemon" \
		|| elog "Enable the daemon: systemctl enable --now mullvad-daemon"
}
