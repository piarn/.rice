#!/usr/bin/env bash
# Compiles quickshell from a pinned source into ~/.local/opt/quickshell, for every
# distro but Gentoo, whose ebuild already compiles it. The same version everywhere,
# with the same features, so the desktop doesn't depend on who packages it.
#
#   ./build-quickshell.sh             build and install
#   ./build-quickshell.sh --deps      install the build dependencies first (sudo)
#   ./build-quickshell.sh --if-stale  only if it's missing, or Qt changed since the build
#   ./build-quickshell.sh --check     is it installed, and built for this Qt?
#   ./build-quickshell.sh --uninstall remove it
#
# Quickshell uses Qt's private APIs, so upstream requires a rebuild for every Qt
# release, or it crashes. `dots upgrade` runs this with --if-stale afterwards.
set -euo pipefail

VERSION=0.3.2
REVISION=4f508be500dea6e5732cc3d50382a0048b17e7b1
URL="https://github.com/quickshell-mirror/quickshell/archive/refs/tags/v$VERSION.tar.gz"
SHA512=b7af28e2d974076aeb62ac27b9b79e8f7e2ef73741ae9c61aab61cadcfb991d32c6593221e24ceb6905303f071059d6205327fdc34012fd9c463917eec89ccb2
MIN_QT=6.6

# Quickshell needs a protocol that older distros' wayland-protocols lacks (Debian 13).
# It's only XML read at build time, so a pinned copy goes in the build directory.
WP_VERSION=1.50
WP_URL="https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/$WP_VERSION/downloads/wayland-protocols-$WP_VERSION.tar.xz"
WP_SHA512=12cdc1c1d45e547f4216445f8f21a58cf3979bcf291ebc0270eda716af2fa39e482eb37c88edce9768a299b8da832421ef3cac64eb3abd5b2230a5d5f488f171

PREFIX="$HOME/.local/opt/quickshell"
BIN_DIR="$HOME/.local/bin"
WORK="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-build"
STAMP="$PREFIX/built-against-qt"

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

as_root() {
    if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

version_at_least() {
    local have=$1 min=$2
    [ "${have%%.*}" -gt "${min%%.*}" ] && return 0
    [ "${have%%.*}" -lt "${min%%.*}" ] && return 1
    have=${have#*.} min=${min#*.}
    [ "${have%%.*}" -ge "${min%%.*}" ]
}

# Fails early on a distro whose Qt is too old, before downloading gigabytes of it.
check_available_qt() {
    local candidate
    command -v apt-cache >/dev/null 2>&1 || return 0
    as_root apt-get update -qq
    candidate=$(apt-cache policy qt6-base-dev | sed -n 's/^ *Candidate: \([0-9]*:\)\{0,1\}\([0-9]*\.[0-9]*\).*/\2/p')
    [ -n "$candidate" ] || return 0
    version_at_least "$candidate" "$MIN_QT" \
        || die "quickshell needs Qt $MIN_QT or newer, and this distro has Qt $candidate. Upgrade the distro, or use the terminal profile."
}

# Build dependencies, then what it needs at run time. Hyprland, X11 and the crash
# handler are compiled out (see configure), so nothing for them is needed.
install_deps() {
    if command -v pacman >/dev/null 2>&1; then
        as_root pacman -S --needed --noconfirm base-devel cmake ninja pkgconf cli11 qt6-base qt6-declarative \
            qt6-shadertools qt6-svg qt6-wayland spirv-tools libdrm mesa vulkan-headers wayland wayland-protocols \
            pipewire pam polkit glib2 jemalloc
    elif command -v apt-get >/dev/null 2>&1; then
        check_available_qt
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            g++ cmake ninja-build pkg-config xz-utils libcli11-dev qt6-base-dev qt6-base-private-dev \
            qt6-declarative-dev qt6-declarative-private-dev qt6-shadertools-dev qt6-svg-dev \
            qt6-wayland-dev qt6-wayland-private-dev spirv-tools libdrm-dev libgbm-dev libegl-dev libvulkan-dev \
            libwayland-dev wayland-protocols libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev \
            libpolkit-gobject-1-dev libglib2.0-dev libjemalloc-dev \
            qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtqml-workerscript qt6-wayland libqt6svg6
    elif command -v dnf >/dev/null 2>&1; then
        as_root dnf install -y --setopt=install_weak_deps=False gcc-c++ cmake ninja-build pkgconf-pkg-config cli11-devel \
            qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtdeclarative-private-devel \
            qt6-qtshadertools-devel qt6-qtsvg-devel qt6-qtwayland-devel spirv-tools \
            libdrm-devel mesa-libgbm-devel mesa-libEGL-devel vulkan-headers wayland-devel wayland-protocols-devel pipewire-devel \
            pam-devel polkit-devel glib2-devel jemalloc-devel qt6-qtdeclarative qt6-qtsvg qt6-qtwayland
    elif command -v zypper >/dev/null 2>&1; then
        as_root zypper --non-interactive install --no-recommends gcc-c++ cmake ninja pkgconf cli11-devel \
            qt6-base-devel qt6-base-private-devel qt6-declarative-devel qt6-declarative-private-devel \
            qt6-shadertools-devel qt6-svg-devel qt6-wayland-devel qt6-wayland-private-devel spirv-tools \
            libdrm-devel libgbm-devel Mesa-libEGL-devel vulkan-headers wayland-devel wayland-protocols-devel pipewire-devel \
            pam-devel polkit-devel glib2-devel jemalloc-devel qt6-declarative-imports qt6-wayland
    else
        die "unknown package manager; the dependencies are listed in quickshell's BUILD.md"
    fi
}

# The Qt the installed binary actually loads, from the library's file name.
linked_qt() {
    local lib
    lib=$(ldd "$PREFIX/bin/quickshell" 2>/dev/null | sed -n 's/.*libQt6Core[^ ]* => \([^ ]*\).*/\1/p' | head -n 1)
    [ -n "$lib" ] || return 0
    lib=$(readlink -f "$lib")
    echo "${lib##*.so.}"
}

is_current() {
    [ -x "$PREFIX/bin/quickshell" ] && [ -r "$STAMP" ] || return 1
    [ "$(cat "$STAMP")" = "$VERSION $(linked_qt)" ]
}

# Points this build at the pinned protocols, if the system's are too old.
use_newer_protocols_if_needed() {
    local dir
    dir=$(pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null || true)
    [ ! -e "$dir/staging/ext-background-effect/ext-background-effect-v1.xml" ] || return 0
    say "this distro's wayland-protocols is too old; using $WP_VERSION for this build"
    mkdir -p "$WORK/wp/pc"
    curl -fsSL --retry 2 -o "$WORK/wp.tar.xz" "$WP_URL"
    [ "$(sha512sum "$WORK/wp.tar.xz" | cut -d' ' -f1)" = "$WP_SHA512" ] \
        || die "wayland-protocols doesn't match its pinned hash; not building it"
    tar -xJf "$WORK/wp.tar.xz" -C "$WORK/wp" --strip-components=1
    cat >"$WORK/wp/pc/wayland-protocols.pc" <<EOF
pkgdatadir=$WORK/wp

Name: Wayland Protocols
Description: Pinned for building quickshell
Version: $WP_VERSION
EOF
    export PKG_CONFIG_PATH="$WORK/wp/pc${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
}

build() {
    local qt jobs
    command -v cmake >/dev/null 2>&1 || die "cmake isn't installed (./build-quickshell.sh --deps)"
    qt=$(pkg-config --modversion Qt6Core 2>/dev/null || true)
    [ -n "$qt" ] || die "Qt 6 development files aren't installed (./build-quickshell.sh --deps)"
    version_at_least "$qt" "$MIN_QT" || die "quickshell needs Qt $MIN_QT or newer, and this system has Qt $qt"

    rm -rf "$WORK"
    mkdir -p "$WORK/src"
    say "downloading quickshell $VERSION"
    curl -fsSL --retry 2 -o "$WORK/src.tar.gz" "$URL"
    [ "$(sha512sum "$WORK/src.tar.gz" | cut -d' ' -f1)" = "$SHA512" ] \
        || die "the download doesn't match its pinned hash; not building it"
    tar -xzf "$WORK/src.tar.gz" -C "$WORK/src" --strip-components=1
    use_newer_protocols_if_needed

    # Half the cores: it's a heavy C++ build, and this is someone's working machine
    jobs=${QS_JOBS:-$(( $(nproc) / 2 + 1 ))}
    say "compiling against Qt $qt with $jobs jobs (several minutes)"
    # X11 and Hyprland: this desktop is sway on Wayland. The crash handler needs
    # cpptrace, which few distros carry; qs-watchdog restarts quickshell instead.
    cmake -GNinja -S "$WORK/src" -B "$WORK/build" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DINSTALL_QML_PREFIX=lib/qt6/qml \
        -DDISTRIBUTOR="~/.rice build-quickshell.sh" \
        -DGIT_REVISION="$REVISION" \
        -DCRASH_HANDLER=OFF \
        -DX11=OFF \
        -DHYPRLAND=OFF -DHYPRLAND_IPC=OFF -DHYPRLAND_GLOBAL_SHORTCUTS=OFF \
        -DHYPRLAND_FOCUS_GRAB=OFF -DHYPRLAND_SURFACE_EXTENSIONS=OFF \
        -DSCREENCOPY_HYPRLAND_TOPLEVEL=OFF >"$WORK/configure.log" 2>&1 \
        || { tail -n 25 "$WORK/configure.log" >&2; die "configuring failed; full log: $WORK/configure.log"; }
    cmake --build "$WORK/build" --parallel "$jobs" >"$WORK/build.log" 2>&1 \
        || { tail -n 25 "$WORK/build.log" >&2; die "compiling failed; full log: $WORK/build.log"; }

    rm -rf "$PREFIX"
    cmake --install "$WORK/build" >/dev/null
    mkdir -p "$BIN_DIR"
    ln -sf "$PREFIX/bin/quickshell" "$BIN_DIR/quickshell"
    ln -sf "$PREFIX/bin/quickshell" "$BIN_DIR/qs"
    echo "$VERSION $(linked_qt)" >"$STAMP"
    rm -rf "$WORK"
    "$PREFIX/bin/quickshell" --version
}

DO_DEPS=0 ACTION=build
while [ $# -gt 0 ]; do
    case $1 in
        --deps) DO_DEPS=1 ;;
        --if-stale) ACTION=if-stale ;;
        --check) ACTION=check ;;
        --uninstall) ACTION=uninstall ;;
        -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

case $ACTION in
    check)
        [ -x "$PREFIX/bin/quickshell" ] || die "not installed: $PREFIX/bin/quickshell"
        is_current || die "built for $(cat "$STAMP" 2>/dev/null), but this system has Qt $(linked_qt); rebuild it"
        "$PREFIX/bin/quickshell" --version
        ;;
    uninstall)
        rm -rf "${PREFIX:?}" "${WORK:?}"
        [ "$(readlink "$BIN_DIR/quickshell" 2>/dev/null)" != "$PREFIX/bin/quickshell" ] || rm -f "$BIN_DIR/quickshell" "$BIN_DIR/qs"
        say "removed $PREFIX"
        ;;
    if-stale)
        if is_current; then
            say "quickshell $VERSION is current"
        else
            [ "$DO_DEPS" = 0 ] || install_deps
            build
        fi
        ;;
    build)
        [ "$DO_DEPS" = 0 ] || install_deps
        build
        ;;
esac
