#!/usr/bin/env bash
# The desktop profile: sway + quickshell and the GUI side of the machine,
# installed on top of ~/.dots' terminal profile. Normally run by
# `~/.dots/install.sh desktop` (which saves the profile and runs this
# last); running it directly re-applies just the desktop part.
#
#   ./install.sh               install / re-link the desktop
#   ./install.sh --doctor      read-only health check of the desktop
#   ./install.sh --outdated    pinned versions (satty, quickshell) behind upstream
#   ./install.sh --ci          package/build steps only (CI containers)
#   ./install.sh --uninstall   unlink the desktop configs (packages stay)
set -euo pipefail

RICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$RICE_DIR/desktop"
BOOTSTRAP_DIR="$RICE_DIR/.bootstrap"
DOTS_DIR="${DOTS_DIR:-$HOME/.dots}"
if [ ! -f "$DOTS_DIR/.bootstrap/lib.sh" ]; then
    echo "error: the desktop installs on top of ~/.dots; clone it and run ~/.dots/install.sh desktop" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$DOTS_DIR/.bootstrap/lib.sh"

DESKTOP_PACKAGES=(firefox foot hidden-apps quickshell satty scripts sway)

# shellcheck disable=SC2034  # read by .bootstrap/lib.sh
declare -A RELEASE_VERSIONS=([satty]=v0.22.0)
# shellcheck disable=SC2034
declare -A RELEASE_REPOS=([satty]=Satty-org/Satty)

# Quickshell ships no prebuilt binary (no AppImage, no GitHub release
# tarball like yazi/lazygit get) and Fedora/Debian/Arch each package
# their own point release, sometimes months apart — risky for something
# this whole desktop is built against the QML API of (quickshell itself
# warns it can break across Qt updates). Built from source instead,
# pinned to one tag, identical on every distro. Installs to ~/.local (no
# sudo needed for the build itself, just for its distro build deps);
# `qs` is a convenience symlink distro packages add that upstream's own
# build doesn't produce, so this makes one too.
QUICKSHELL_VERSION=v0.3.1
QUICKSHELL_VERSION_FILE="$HOME/.local/share/dots-quickshell-version"
QT_FALLBACK_VERSION=6.8.3

install_quickshell() {
    if [ -x "$LOCAL_BIN/quickshell" ] \
        && [ "$(cat "$QUICKSHELL_VERSION_FILE" 2>/dev/null)" = "$QUICKSHELL_VERSION" ]; then
        return
    fi

    echo "==> installing quickshell $QUICKSHELL_VERSION's build dependencies"
    case "$(package_manager)" in
        dnf)
            sudo dnf install -y cmake ninja-build pkgconf-pkg-config gcc-c++ \
                qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtwayland-devel \
                qt6-qt5compat-devel qt6-qtimageformats qt6-qtshadertools-devel \
                libdrm-devel wayland-devel wayland-protocols-devel mesa-libgbm-devel \
                vulkan-headers spirv-tools-devel cli11-devel pipewire-devel \
                pam-devel polkit-devel jemalloc-devel libunwind-devel python3 ;;
        apt)
            sudo apt update && sudo apt install -y cmake ninja-build pkgconf g++ \
                qt6-base-dev qt6-declarative-dev qt6-wayland-dev qt6-shadertools-dev \
                qt6-base-private-dev qt6-declarative-private-dev qt6-wayland-private-dev \
                libcli11-dev libwayland-dev wayland-protocols libpipewire-0.3-dev \
                libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev libglib2.0-dev \
                libdrm-dev libgbm-dev libjemalloc-dev libegl-dev libgles-dev libvulkan-dev \
                libxcb1-dev spirv-tools libunwind-dev python3-venv ;;
        pacman)
            sudo pacman -S --needed --noconfirm base-devel cmake ninja pkgconf \
                cli11 qt6-shadertools spirv-tools vulkan-headers wayland-protocols \
                qt6-base qt6-declarative qt6-wayland wayland libdrm libpipewire pam \
                polkit mesa libxcb libunwind jemalloc python ;;
        *)
            echo "error: no supported package manager (apt/dnf/pacman) for quickshell's build deps" >&2
            exit 1 ;;
    esac

    # quickshell needs Qt >= 6.6; Ubuntu 24.04 ships 6.4. Fall back to an
    # upstream Qt build (aqtinstall) in ~/.local/qt, rpath'd into the binary
    # so nothing needs LD_LIBRARY_PATH at runtime.
    local qt_ver qt_args=()
    qt_ver=$(pkg-config --modversion Qt6Core 2>/dev/null || echo 0)
    if [ "$(printf '%s\n6.6.0\n' "$qt_ver" | sort -V | head -1)" != "6.6.0" ]; then
        local qt_root="$HOME/.local/qt" qt_dir
        qt_dir="$qt_root/$QT_FALLBACK_VERSION/gcc_64"
        if [ ! -d "$qt_dir/lib/cmake/Qt6" ]; then
            if [ "$(uname -m)" != x86_64 ]; then
                echo "error: system Qt $qt_ver is too old for quickshell and no fallback Qt exists for $(uname -m)" >&2
                exit 1
            fi
            echo "==> system Qt is $qt_ver (< 6.6); installing Qt $QT_FALLBACK_VERSION via aqtinstall"
            local venv
            venv=$(mktemp -d)
            python3 -m venv "$venv"
            "$venv/bin/pip" install -q aqtinstall
            "$venv/bin/aqt" install-qt linux desktop "$QT_FALLBACK_VERSION" linux_gcc_64 \
                -m qt5compat qtshadertools qtimageformats -O "$qt_root"
            rm -rf "$venv"
        fi
        qt_args=(-DCMAKE_PREFIX_PATH="$qt_dir" -DCMAKE_INSTALL_RPATH="$qt_dir/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON)
    fi

    echo "==> building quickshell $QUICKSHELL_VERSION from source (a few minutes)"
    local tmp
    tmp=$(mktemp -d)
    git clone --branch "$QUICKSHELL_VERSION" --depth 1 \
        https://git.outfoxxed.me/outfoxxed/quickshell "$tmp/quickshell"
    (
        cd "$tmp/quickshell"
        # cpptrace (crash handler) has no Ubuntu/Fedora package; let quickshell fetch it
        cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release -DVENDOR_CPPTRACE=ON -DCMAKE_INSTALL_PREFIX="$HOME/.local" "${qt_args[@]}"
        cmake --build build
        cmake --install build
    )
    rm -rf "$tmp"

    ln -sf "$LOCAL_BIN/quickshell" "$LOCAL_BIN/qs"
    mkdir -p "$(dirname "$QUICKSHELL_VERSION_FILE")"
    echo "$QUICKSHELL_VERSION" >"$QUICKSHELL_VERSION_FILE"
}

# Installs every app in .bootstrap/flatpaks.txt (one Flathub app id per
# line) that isn't installed yet, system-wide like Fedora's own flatpak
# setup, adding the Flathub remote first if it's missing.
install_flatpaks() {
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "warning: flatpak not found; skipping .bootstrap/flatpaks.txt" >&2
        return
    fi
    local app missing=()
    while IFS= read -r app; do
        case "$app" in ''|'#'*) continue ;; esac
        flatpak info "$app" >/dev/null 2>&1 || missing+=("$app")
    done <"$BOOTSTRAP_DIR/flatpaks.txt"
    if [ ${#missing[@]} -eq 0 ]; then
        echo "==> flatpaks already installed, nothing to do"
        return
    fi
    echo "==> installing flatpaks: ${missing[*]}"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y --noninteractive flathub "${missing[@]}"
}

# The session's polkit agent (password prompts for privileged actions,
# run by polkit-agent.service): mate-polkit, the one agent packaged under
# the same name on Fedora, Debian/Ubuntu and Arch. Its binary is never on
# PATH (a different libexec dir per distro), so it can't go through
# packages.txt's `command -v` check; desktop/scripts/.local/bin/polkit-agent
# holds the list of places it can be.
polkit_agent_installed() {
    local agent
    # not a pipeline into the loop: under pipefail its status would be the
    # last candidate's [ -x ], failing whenever that one isn't this distro's
    for agent in $(grep -o '/usr/lib[a-z]*/[^ ]*-authentication-agent-1' "$DESKTOP_DIR/scripts/.local/bin/polkit-agent"); do
        [ -x "$agent" ] && return 0
    done
    return 1
}

install_polkit_agent() {
    polkit_agent_installed && return
    echo "==> installing a polkit agent (mate-polkit)"
    pkg_install mate-polkit -- mate-polkit -- mate-polkit
}

# No apt/dnf package; ships a prebuilt glibc binary using the same
# target-triple naming as yazi's release assets.
install_satty() { install_from_github_release satty "${YAZI_ARCH:+${YAZI_ARCH}.tar.gz}" satty; }

# Material Symbols Outlined: the island's icon font (consistent stroke
# weight/style across every glyph); components/Icon.qml pins it to its
# "Regular" named instance so weight/fill don't drift.
install_material_symbols() {
    fc-list 2>/dev/null | grep "Material Symbols Outlined" >/dev/null && return
    echo "==> installing Material Symbols Outlined (icons for quickshell)"
    local font_dir="$HOME/.local/share/fonts/MaterialSymbols"
    mkdir -p "$font_dir"
    curl -fsSL -o "$font_dir/MaterialSymbolsOutlined.ttf" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
    fc-cache -f "$font_dir" >/dev/null 2>&1
}

# quickshell's lock screen authenticates via PamContext against its own
# PAM service: `auth include login` reuses the distro's normal auth stack
# (so e.g. fprintd still works) without login's session rules.
install_pam_lock_config() {
    local pam_file="/etc/pam.d/quickshell-lock" content='auth include login'
    [ "$(cat "$pam_file" 2>/dev/null)" = "$content" ] && return
    echo "==> installing $pam_file"
    echo "$content" | sudo tee "$pam_file" >/dev/null
}

# The login screen and the session it starts — what decides whether the
# machine comes up usable after a boot:
#  - greetd owns tty1 (getty@tty1 and ly are disabled) and runs
#    /usr/local/bin/dots-greeter as the greetd user: the quickshell login
#    screen (desktop/quickshell/.config/quickshell/greeter.qml) in a bare
#    sway. It falls back to greetd's text login (agreety) whenever the
#    graphical one fails, hangs or is escaped with Ctrl+Alt+Backspace.
#  - The greeter runs quickshell from /usr/local/libexec/dots-greeter (the
#    greetd user can't reach ~/.local/bin) and its QML/theme from
#    /var/lib/dots-greeter, a directory this user owns so greeter-sync
#    keeps it current without sudo.
#  - Both the greeter and the "sway" session start through
#    /usr/local/bin/sway-session (GPU selection, a log, a safe-mode retry
#    for the desktop). The "terminal" session is a plain login shell.
#  - Ctrl+Alt+F2 and up still give a text login (logind's autovt).
GREETD_CONFIG=/etc/greetd/config.toml
GREETER_SWAY=/etc/greetd/dots-greeter.sway
GREETER_DIR=/var/lib/dots-greeter
GREETER_QS=/usr/local/libexec/dots-greeter/quickshell

# sudo install of $1 to $2 (mode $3) unless it's already identical.
install_system_file() {
    cmp -s "$1" "$2" && return
    echo "==> installing $2"
    sudo install -D -m "$3" "$1" "$2"
}

install_login() {
    pkg_install greetd greetd-selinux -- greetd -- greetd

    install_system_file "$BOOTSTRAP_DIR/sway-session" /usr/local/bin/sway-session 755
    install_system_file "$BOOTSTRAP_DIR/dots-greeter" /usr/local/bin/dots-greeter 755
    install_system_file "$LOCAL_BIN/quickshell" "$GREETER_QS" 755
    local sway_conf
    sway_conf=$(mktemp)
    sed "s|@USER@|$USER|g" "$BOOTSTRAP_DIR/greetd/dots-greeter.sway" >"$sway_conf"
    install_system_file "$sway_conf" "$GREETER_SWAY" 644
    rm -f "$sway_conf"
    install_system_file "$BOOTSTRAP_DIR/greetd/config.toml" "$GREETD_CONFIG" 644

    if [ ! -w "$GREETER_DIR" ]; then
        echo "==> creating $GREETER_DIR (the login screen's copy of the shell and theme)"
        sudo install -d -o "$USER" -g "$(id -gn)" -m 755 "$GREETER_DIR"
    fi
    "$DESKTOP_DIR/scripts/.local/bin/greeter-sync"
    # where the palette lived before it moved into the shell copy (shell/theme)
    rm -rf "${GREETER_DIR:?}/rice"

    # The old ly setup's Sway entry; the greeter starts sway-session itself.
    [ -e /usr/local/share/wayland-sessions/sway.desktop ] \
        && sudo rm -f /usr/local/share/wayland-sessions/sway.desktop

    # Only takes effect at the next boot: the running session may well
    # have been started by ly, and stopping it now would end it.
    local unit
    for unit in ly@tty1.service getty@tty1.service; do
        if systemctl is-enabled -q "$unit" 2>/dev/null; then
            echo "==> disabling $unit (greetd owns tty1 from the next boot)"
            sudo systemctl disable "$unit" >/dev/null 2>&1 || true
        fi
    done
    if ! systemctl is-enabled -q greetd.service 2>/dev/null; then
        echo "==> enabling greetd (from the next boot)"
        sudo systemctl enable greetd.service
    fi
}

# sway/outputs.conf is per-machine (gitignored) and normally written by
# apply-layout, which needs a running sway. Seed the laptop layout — it
# has no explicit resolution, so it suits any machine — so sway's
# `include` doesn't dangle on a fresh clone; --auto replaces it later.
seed_outputs() {
    [ -e "$RICE_DIR/sway/outputs.conf" ] && return
    [ -f "$RICE_DIR/layouts/laptop.conf" ] || return 0
    echo "==> seeding sway/outputs.conf from the laptop layout"
    mkdir -p "$RICE_DIR/sway"
    { echo "# generated by install.sh from $RICE_DIR/layouts/laptop.conf"
      cat "$RICE_DIR/layouts/laptop.conf"; } >"$RICE_DIR/sway/outputs.conf"
}

preflight() {
    local problems=() host extra=()
    echo "==> preflight (desktop): checking dependencies (read-only)"
    polkit_agent_installed || extra+=(mate-polkit)
    mapfile -t problems < <(preflight_packages "$BOOTSTRAP_DIR/packages.txt" "${extra[@]}")
    if command -v curl >/dev/null 2>&1; then
        for host in github.com git.outfoxxed.me dl.flathub.org; do
            curl -fsS --head --max-time 10 "https://$host" >/dev/null 2>&1 \
                || problems+=("cannot reach https://$host")
        done
    fi
    if [ ${#problems[@]} -gt 0 ]; then
        echo "error: preflight failed, nothing was changed:" >&2
        printf '  - %s\n' "${problems[@]}" >&2
        exit 1
    fi
    echo "==> preflight OK"
}

doctor() {
    local name missing=()
    doctor_init
    echo "desktop packages"
    mapfile -t missing < <(missing_packages "$BOOTSTRAP_DIR/packages.txt")
    if [ ${#missing[@]} -eq 0 ]; then ok "packages.txt"; else bad "not installed: ${missing[*]}"; fi
    polkit_agent_installed && ok "polkit agent" || bad "no polkit agent (mate-polkit)"
    doctor_releases ok bad satty
    if [ "$(cat "$QUICKSHELL_VERSION_FILE" 2>/dev/null)" = "$QUICKSHELL_VERSION" ] && [ -x "$LOCAL_BIN/quickshell" ]; then
        ok "quickshell $QUICKSHELL_VERSION"
    else
        bad "quickshell isn't the pinned $QUICKSHELL_VERSION build"
    fi
    if command -v flatpak >/dev/null 2>&1; then
        missing=()
        while IFS= read -r name; do
            case "$name" in ''|'#'*) continue ;; esac
            flatpak info "$name" >/dev/null 2>&1 || missing+=("$name")
        done <"$BOOTSTRAP_DIR/flatpaks.txt"
        if [ ${#missing[@]} -eq 0 ]; then ok "flatpaks.txt"; else bad "flatpaks not installed: ${missing[*]}"; fi
    fi
    fc-list 2>/dev/null | grep "Material Symbols Outlined" >/dev/null && ok "Material Symbols font" || bad "Material Symbols font missing"
    [ -f /etc/pam.d/quickshell-lock ] && ok "lock screen PAM service" || bad "/etc/pam.d/quickshell-lock missing (lock screen can't unlock)"

    echo "boot"
    local f
    for f in "$BOOTSTRAP_DIR/sway-session:/usr/local/bin/sway-session" \
             "$BOOTSTRAP_DIR/dots-greeter:/usr/local/bin/dots-greeter" \
             "$BOOTSTRAP_DIR/greetd/config.toml:$GREETD_CONFIG" \
             "$LOCAL_BIN/quickshell:$GREETER_QS"; do
        cmp -s "${f%%:*}" "${f#*:}" && ok "${f#*:}" || bad "${f#*:} missing or differs from ${f%%:*} (run install.sh)"
    done
    if sed "s|@USER@|$USER|g" "$BOOTSTRAP_DIR/greetd/dots-greeter.sway" | cmp -s - "$GREETER_SWAY"; then
        ok "$GREETER_SWAY"
    else
        bad "$GREETER_SWAY missing or out of date (run install.sh)"
    fi
    systemctl is-enabled -q greetd.service 2>/dev/null && ok "greetd enabled" || bad "greetd not enabled (run install.sh)"
    for f in ly@tty1.service getty@tty1.service; do
        if systemctl is-enabled -q "$f" 2>/dev/null; then
            bad "$f is enabled and contends with greetd for tty1 (run install.sh)"
        fi
    done
    if command -v ly >/dev/null 2>&1; then
        if systemctl is-active -q ly@tty1.service 2>/dev/null; then
            warn "ly is still installed (this session came from it); after a reboot: sudo dnf remove ly"
        else
            warn "ly is still installed, unused: sudo dnf remove ly"
        fi
    fi
    if "$DESKTOP_DIR/scripts/.local/bin/greeter-sync" --check; then
        ok "login screen's copy of the shell and theme is current"
    else
        bad "$GREETER_DIR is out of date (greeter-sync)"
    fi
    if [ -f "$HOME/.local/state/sway.log" ] && grep -q "retrying in safe mode" "$HOME/.local/state/sway.log"; then
        bad "the last sway start fell back to safe mode; see ~/.local/state/sway.log"
    fi

    echo "desktop links"
    local entries=() fails_before=$DOCTOR_FAILS
    for name in "${DESKTOP_PACKAGES[@]}"; do entries+=("$DESKTOP_DIR:$name"); done
    doctor_links ok bad "${entries[@]}" || true
    [ "$DOCTOR_FAILS" -gt "$fails_before" ] || ok "every desktop package is linked"
    [ -e "$RICE_DIR/sway/outputs.conf" ] && ok "sway/outputs.conf" || bad "$RICE_DIR/sway/outputs.conf missing (sway's include dangles)"

    echo "session"
    if swaymsg -t get_version >/dev/null 2>&1; then
        pgrep -x quickshell >/dev/null && ok "quickshell running" || bad "quickshell not running"
        local units
        units=$(systemctl --user show -p Wants --value dots-session.target 2>/dev/null)
        systemctl --user -q is-active dots-session.target \
            || bad "dots-session.target not active (log out and back in, or: systemctl --user restart dots-session.target)"
        for name in $units; do
            if systemctl --user -q is-active "$name"; then
                ok "$name"
            else
                bad "$name $(systemctl --user show -p ActiveState --value "$name") (journalctl --user -u $name)"
            fi
        done
        if sway --unsupported-gpu -C >/dev/null 2>&1; then
            ok "sway config valid (sway -C)"
        else
            bad "sway config has errors (sway --unsupported-gpu -C); dots-reload won't reload it"
        fi
        # sway hands back the main config text it loaded; includes aren't covered
        if swaymsg -t get_config \
            | python3 -c 'import json, sys; sys.exit(json.load(sys.stdin)["config"] != open(sys.argv[1]).read())' \
                "$HOME/.config/sway/config"; then
            ok "sway config current"
        else
            bad "sway is running an older ~/.config/sway/config than the one on disk (run dots-reload)"
        fi
    else
        warn "not inside sway; skipped the session checks"
    fi

    echo "repo"
    if [ -n "$(git -C "$RICE_DIR" status --porcelain 2>/dev/null)" ]; then
        warn "$RICE_DIR has uncommitted changes"
    else
        ok "$RICE_DIR clean"
    fi

    echo
    if [ "$DOCTOR_FAILS" -gt 0 ]; then
        echo "$DOCTOR_FAILS problem(s), $DOCTOR_WARNS warning(s)"
        return 1
    fi
    echo "all good ($DOCTOR_WARNS warning(s))"
}

outdated() {
    local status=0 latest
    outdated_releases satty || status=$?
    latest=$(git ls-remote --tags --refs https://git.outfoxxed.me/outfoxxed/quickshell 2>/dev/null \
        | sed -n 's|.*refs/tags/\(v[0-9.]*\)$|\1|p' | sort -V | tail -1)
    if [ -z "$latest" ]; then
        echo "error: couldn't look up the latest quickshell tag" >&2
        status=2
    elif [ "$latest" != "$QUICKSHELL_VERSION" ]; then
        echo "quickshell $QUICKSHELL_VERSION -> $latest"
        [ "$status" -eq 2 ] || status=1
    fi
    return "$status"
}

# --ci (.github/workflows/install.yml, as root in a fresh distro container):
# everything that installs from a package manager or a download.
ci() {
    preflight
    install_packages "$BOOTSTRAP_DIR/packages.txt"
    install_polkit_agent
    install_quickshell
    install_satty
    "$LOCAL_BIN/quickshell" --version
    polkit_agent_installed
}

uninstall() {
    unstow_packages "$DESKTOP_DIR" "${DESKTOP_PACKAGES[@]}"
    systemctl --user stop dots-session.target >/dev/null 2>&1 || true
    prune_dangling_links
    reload_user_units
    echo "Desktop configs unlinked (packages, flatpaks and the login entry are left installed)."
}

case "${1:-}" in
    --doctor) doctor; exit ;;
    --outdated) outdated; exit ;;
    --ci) ci; exit ;;
    --uninstall) uninstall; exit ;;
    '') ;;
    *) sed -n '7,11p' "$0" | sed 's/^# \{0,1\}/usage: /' >&2; exit 1 ;;
esac

preflight
install_packages "$BOOTSTRAP_DIR/packages.txt"
install_polkit_agent
install_quickshell
install_flatpaks
install_material_symbols
install_pam_lock_config
install_login
install_satty

seed_outputs
stow_packages "$DESKTOP_DIR" "${DESKTOP_PACKAGES[@]}"
prune_dangling_links
reload_user_units
if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
    "$RICE_DIR/bin/apply-layout" --auto
fi
echo "==> desktop installed"
