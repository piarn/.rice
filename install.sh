#!/usr/bin/env bash
# Puts the sway desktop onto a Linux machine, on top of ~/.dotfiles. Safe to re-run.
#
#   ./install.sh            packages (sudo), quickshell, links, fonts, portal, default apps
#   ./install.sh --link     links only: no sudo, no network
#   ./install.sh --apps     also the flatpak apps in apps.txt
#   ./install.sh --no-sudo  only what needs no root
#   ./install.sh --dry-run  show the plan, change nothing
#
# Each directory listed in PACKAGES mirrors $HOME; its files become symlinks
# there, and whatever is in the way moves to the backup directory. Terminal theming
# (bat, btop, tmux, yazi) is in ~/.dotfiles, so it follows you to any desktop.
#
# The system-wide choices (SSH, firewall) are never applied from here: system/apply.sh.
set -euo pipefail

if [ "$(id -u)" -eq 0 ] && [ "${DOTS_ALLOW_ROOT:-0}" != 1 ]; then
    echo "error: run install.sh as yourself; it asks for sudo where it needs it" >&2
    exit 1
fi

RICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="${DOTS_DIR:-$HOME/.dotfiles}"
if [ ! -r "$DOTS_DIR/.bootstrap/lib.sh" ]; then
    echo "error: ~/.rice sits on top of ~/.dotfiles, which isn't there; clone it first" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$DOTS_DIR/.bootstrap/lib.sh"
BACKUP_DIR="$STATE_DIR/backup-rice/$(date +%Y%m%d-%H%M%S)"

PACKAGES=(foot portal quickshell sway swaylock)
MANIFEST="$RICE_DIR/packages.tsv"
OVERLAY_DIR="$HOME/.overlay"
FILE_PICKER_PORTAL=termfilechooser.portal

# ---------------------------------------------------------------- packages

# X11 apps (Steam, Zoom) need Xwayland. The Gentoo build of sway leaves X11 out
# on purpose, so it's only pulled in elsewhere.
desktop_groups() {
    if [ "$PM" = portage ]; then echo "desktop gentoo"; else echo "desktop xwayland"; fi
}

# The repos @rice draws from: guru (quickshell), librewolf, and the local overlay
# with the file picker portal. net-vpn/netbird-bin stays out of this repo on purpose.
setup_gentoo_repos() {
    local repo
    for repo in guru librewolf; do
        [ -d "/var/db/repos/$repo" ] || as_root eselect repository enable "$repo"
        [ -d "/var/db/repos/$repo/metadata" ] || as_root emaint sync -r "$repo"
    done
    if [ ! -f "$OVERLAY_DIR/profiles/repo_name" ]; then
        mkdir -p "$OVERLAY_DIR/profiles" "$OVERLAY_DIR/metadata"
        echo local >"$OVERLAY_DIR/profiles/repo_name"
        printf 'masters = gentoo\nthin-manifests = true\nauto-sync = false\n' >"$OVERLAY_DIR/metadata/layout.conf"
    fi
    if ! grep -qs '^\[local\]' /etc/portage/repos.conf/local.conf; then
        printf '[local]\nlocation = %s\nauto-sync = no\n' "$OVERLAY_DIR" | as_root tee /etc/portage/repos.conf/local.conf >/dev/null
    fi
    # Portage runs as its own user, so everything here must be world-readable
    (cd "$RICE_DIR/portage/overlay" && find . -type f | sed 's|^\./||') | while IFS= read -r rel; do
        mkdir -p "$(dirname "$OVERLAY_DIR/$rel")"
        cmp -s "$RICE_DIR/portage/overlay/$rel" "$OVERLAY_DIR/$rel" || cp "$RICE_DIR/portage/overlay/$rel" "$OVERLAY_DIR/$rel"
        chmod 644 "$OVERLAY_DIR/$rel"
    done
    find "$OVERLAY_DIR" -type d -exec chmod 755 {} +
}

install_packages() {
    [ "$PM" != portage ] || setup_gentoo_repos
    # shellcheck disable=SC2046
    install_manifest "$MANIFEST" rice $(desktop_groups)
}

# NVIDIA's own driver needs sway 1.12 or newer (see sway-session). Fedora 44 has
# 1.11, so build-sway.sh rebuilds Fedora's 1.12; elsewhere it's only reported.
install_sway_for_nvidia() {
    [ -d /sys/module/nvidia_drm ] || return 0
    "$RICE_DIR/build-sway.sh" --check && return 0
    if [ "$PM" = dnf ] && [ "$NO_SUDO" = 0 ]; then
        "$RICE_DIR/build-sway.sh" || warn "sway 1.12 didn't build, so on NVIDIA parts of the screen may flicker"
    else
        warn "sway is older than 1.12, so on NVIDIA parts of the screen may flicker; install 1.12 or newer"
    fi
}

# Compiled from source everywhere but Gentoo: one pinned version, same features.
# A failed build mustn't stop the rest of the desktop from installing.
install_quickshell() {
    [ "$PM" != portage ] || return 0
    local args=(--if-stale)
    [ "$PM" = none ] || args+=(--deps)
    "$RICE_DIR/build-quickshell.sh" "${args[@]}" || warn "quickshell didn't build, so sway has no launcher or bar; see build-quickshell.sh"
}

report_desktop_gaps() {
    # shellcheck disable=SC2046
    report_missing "$MANIFEST" $(desktop_groups)
}

# ---------------------------------------------------------------- setup steps

# quickshell's launcher icons. No distro packages this font.
install_material_symbols() {
    command -v fc-list >/dev/null 2>&1 || return 0
    fc-list | grep -q "Material Symbols Outlined" && return 0
    local dir="$HOME/.local/share/fonts/MaterialSymbols"
    mkdir -p "$dir"
    curl -fsSL -o "$dir/MaterialSymbolsOutlined.ttf" \
        "https://github.com/google/material-design-icons/raw/10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
        || { warn "Material Symbols font failed"; return 0; }
    fc-cache -f "$dir" >/dev/null 2>&1
}

# Not every distro packages this one (it's what foot and the tmux bar use for
# icons), so it comes from the pinned release where it's missing.
install_nerd_symbols() {
    command -v fc-list >/dev/null 2>&1 || return 0
    fc-list : family | grep -q "Symbols Nerd Font" && return 0
    local dir="$HOME/.local/share/fonts/SymbolsNerdFont" tag=v3.4.0
    mkdir -p "$dir"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/NerdFontsSymbolsOnly.tar.xz" \
        | tar -xJ -C "$dir" || { warn "Symbols Nerd Font failed"; return 0; }
    fc-cache -f "$dir" >/dev/null 2>&1
}

# Not a link, because it depends on the machine: asking the portal for a backend
# that isn't installed makes every file dialog fail. Without termfilechooser the
# GTK dialog stays; the README has how to build it.
setup_portal() {
    local dst="$HOME/.config/xdg-desktop-portal/sway-portals.conf" tmp
    mkdir -p "$(dirname "$dst")"
    tmp=$(mktemp)
    if [ -e "/usr/share/xdg-desktop-portal/portals/$FILE_PICKER_PORTAL" ] \
        || [ -e "/usr/local/share/xdg-desktop-portal/portals/$FILE_PICKER_PORTAL" ]; then
        cat "$RICE_DIR/system/sway-portals.conf" >"$tmp"
    else
        grep -v 'FileChooser=termfilechooser' "$RICE_DIR/system/sway-portals.conf" >"$tmp"
        warn "termfilechooser isn't installed: file dialogs stay GTK, not yazi"
    fi
    cmp -s "$tmp" "$dst" || cp "$tmp" "$dst"
    rm -f "$tmp"
}

# Apps can't see the palette, only this: Flatpaks read it through the portal, and
# their own "system" theme setting follows it. Sandboxed GTK3 apps such as LibreOffice
# stay light from the portal alone, so they get GTK_THEME too. Adwaita's dark variant
# comes with every runtime: no theme extension or sandbox file access is needed.
setup_appearance() {
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark
        gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
    fi
    if command -v flatpak >/dev/null 2>&1; then
        flatpak override --user --env=GTK_THEME=Adwaita:dark
    fi
}

# LibreWolf for links, web files and PDFs, whichever way it's installed here.
set_default_apps() {
    command -v xdg-mime >/dev/null 2>&1 || return 0
    local desktop='' candidate dir
    for candidate in librewolf-bin librewolf io.gitlab.librewolf-community; do
        for dir in /usr/share/applications "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications; do
            [ -e "$dir/$candidate.desktop" ] && { desktop=$candidate.desktop; break 2; }
        done
    done
    [ -n "$desktop" ] || return 0
    xdg-settings set default-web-browser "$desktop" 2>/dev/null || true
    xdg-mime default "$desktop" application/pdf x-scheme-handler/http x-scheme-handler/https text/html
}

# Into every profile that exists. A profile made later gets it on the next run.
link_librewolf_prefs() {
    local profile
    for profile in "$HOME"/.config/librewolf/librewolf/*/ "$HOME"/.librewolf/*/ "$HOME"/.var/app/io.gitlab.librewolf-community/.librewolf/*/; do
        [ -e "$profile/prefs.js" ] || continue
        [ -L "$profile/user.js" ] && [ "$(readlink "$profile/user.js")" = "$RICE_DIR/librewolf/user.js" ] && continue
        [ ! -e "$profile/user.js" ] || mv "$profile/user.js" "$profile/user.js.before-rice"
        ln -sf "$RICE_DIR/librewolf/user.js" "$profile/user.js"
        echo "    linked user.js into ${profile/#"$HOME"/\~}"
    done
}

# Optional: only with --apps, and only where flatpak is usable.
install_flatpak_apps() {
    if ! command -v flatpak >/dev/null 2>&1; then
        warn "--apps needs flatpak, which isn't installed"
        return 0
    fi
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    local line app opts
    while IFS= read -r line; do
        case $line in '' | '#'*) continue ;; esac
        app=${line%% *}
        opts=${line#"$app"}
        flatpak info "$app" >/dev/null 2>&1 || flatpak install --user -y flathub "$app" || warn "couldn't install $app"
        # shellcheck disable=SC2086
        [ -z "$opts" ] || flatpak override --user $opts "$app"
    done <"$RICE_DIR/apps.txt"
    if ! command -v librewolf-bin >/dev/null 2>&1 && ! command -v librewolf >/dev/null 2>&1; then
        flatpak info io.gitlab.librewolf-community >/dev/null 2>&1 \
            || flatpak install --user -y flathub io.gitlab.librewolf-community || warn "couldn't install LibreWolf"
    fi
}

# Patched foot is its own project, built separately. foot-lig opens stock foot
# until that's done, so a fresh machine still has a terminal.
report_foot_lig() {
    "$HOME/.local/opt/foot-ligatures/bin/foot" --version >/dev/null 2>&1 && return 0
    echo "    foot-lig runs stock foot until you build it: see the foot-lig project's README"
}

# ---------------------------------------------------------------- main

ACTION=install
APPS=0
DRY_RUN=0
while [ $# -gt 0 ]; do
    case $1 in
        --link) ACTION=link ;;
        --apps) APPS=1 ;;
        --no-sudo) NO_SUDO=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
    esac
    shift
done

detect_platform

if [ "$PLATFORM" != linux ] || [ "$IS_WSL" = 1 ]; then
    echo "error: this desktop is Wayland on Linux; $(platform_name) only gets ~/.dotfiles's terminal profile" >&2
    exit 1
fi

if [ "$DRY_RUN" = 1 ]; then
    say "desktop plan for $(platform_name), packages via $PM"
    # shellcheck disable=SC2046
    plan_manifest "$MANIFEST" rice $(desktop_groups)
    [ "$PM" = portage ] || echo "  quickshell: compiled from source by build-quickshell.sh, unless already current"
    if [ -d /sys/module/nvidia_drm ] && ! "$RICE_DIR/build-sway.sh" --check; then
        echo "  sway: NVIDIA needs 1.12 or newer$([ "$PM" != dnf ] || echo ', rebuilt from Fedora'"'"'s packaging by build-sway.sh')"
    fi
    echo "  links: ${PACKAGES[*]}"
    exit 0
fi

if [ "$ACTION" = link ]; then
    link_packages "$RICE_DIR" "${PACKAGES[@]}"
    prune_dangling_links "$RICE_DIR"
    exit 0
fi

install_packages
install_sway_for_nvidia
install_quickshell
link_packages "$RICE_DIR" "${PACKAGES[@]}"
prune_dangling_links "$RICE_DIR"
install_material_symbols
install_nerd_symbols
report_desktop_gaps
setup_portal
setup_appearance
set_default_apps
link_librewolf_prefs
[ "$APPS" = 0 ] || install_flatpak_apps
report_foot_lig
say "done. Log in again to pick up the environment and the new configs."
