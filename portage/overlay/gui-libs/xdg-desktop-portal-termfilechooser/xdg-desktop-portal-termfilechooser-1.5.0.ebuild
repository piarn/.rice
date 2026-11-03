# Copyright 2026 Arnas
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="xdg-desktop-portal backend for choosing files with a terminal file manager"
HOMEPAGE="https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser"
SRC_URI="https://github.com/hunkyburrito/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64"

DEPEND="
	dev-libs/inih
	sys-apps/systemd:=
"
RDEPEND="
	${DEPEND}
	sys-apps/xdg-desktop-portal
"
BDEPEND="
	>=app-text/scdoc-1.9.7
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		-Dsd-bus-provider=libsystemd
		-Dsystemd=enabled
		-Dman-pages=enabled
		-Dwerror=false
	)
	meson_src_configure
}
