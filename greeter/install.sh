#!/usr/bin/env bash
# The quickshell login screen, for greetd (see shell.qml). Like system/apply.sh
# it's system-wide, so install.sh never runs it; it shows what it will do and
# asks first.
#
#   greeter/install.sh               install it, and greetd in place of the tty1 login
#   greeter/install.sh --stage DIR   only assemble the config into DIR, no sudo
#                                    (preview: qs -p DIR, with
#                                    QML2_IMPORT_PATH=DIR/theme)
#   greeter/install.sh --remove      back to the tty1 login (works from tty2)
#
# greetd itself comes from the distro: emerge gui-libs/greetd on Gentoo.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shell="$here/../quickshell/.config/quickshell"
dest=/etc/greetd/quickshell
state=/var/lib/qs-greeter

# The greeter, plus the shared pieces it imports, as one standalone config:
# the greetd user can't (and shouldn't) read ~/.rice.
assemble() {
    local out=$1
    mkdir -p "$out/components" "$out/theme/quickshell"
    cp "$here/shell.qml" "$here/GreeterFace.qml" "$here/sway.conf" "$out/"
    cp -L "$shell"/components/{SegmentDigit,Style,MonoText}.qml "$out/components/"
    cp -L "$shell"/theme/quickshell/{Colors.qml,qmldir} "$out/theme/quickshell/"
}

case ${1:-} in
--stage)
    [ -n "${2:-}" ] || { echo "usage: $0 --stage DIR" >&2; exit 2; }
    assemble "$2"
    echo "Assembled in $2. Preview: QML2_IMPORT_PATH=$2/theme qs -p $2"
    exit 0
    ;;
--remove)
    echo "This will, with sudo: disable greetd and re-enable the tty1 login (getty@tty1)."
    printf 'Continue? [y/N] '
    read -r reply
    case $reply in y | Y) ;; *) echo "Nothing changed."; exit 0 ;; esac
    sudo systemctl disable greetd.service
    sudo systemctl enable getty@tty1.service
    echo "Done. Reboot, or: sudo systemctl stop greetd && sudo systemctl start getty@tty1"
    exit 0
    ;;
"") ;;
*) sed -n '2,12p' "$0" >&2; exit 2 ;;
esac

command -v greetd >/dev/null 2>&1 || { echo "error: greetd isn't installed (Gentoo: emerge gui-libs/greetd)" >&2; exit 1; }
getent passwd greetd >/dev/null || { echo "error: no greetd user (Gentoo: acct-user/greetd)" >&2; exit 1; }
command -v qs >/dev/null 2>&1 || { echo "error: quickshell isn't installed" >&2; exit 1; }

echo "This will, with sudo:"
echo "  - install the greeter to $dest/ (replacing what's there)"
echo "  - make $state/ for greetd (last user and session, quickshell's cache)"
echo "  - install greetd.toml as /etc/greetd/config.toml (the old one kept as config.toml.bak)"
echo "  - enable greetd and disable getty@tty1, from the next boot"
printf 'Continue? [y/N] '
read -r reply
case $reply in y | Y) ;; *) echo "Nothing changed."; exit 0 ;; esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
assemble "$tmp"

sudo rm -rf "$dest"
sudo mkdir -p "$dest"
sudo cp -r "$tmp"/. "$dest"/
sudo chown -R root:root "$dest"
sudo find "$dest" -type d -exec chmod 755 {} + -o -type f -exec chmod 644 {} +

sudo install -d -o greetd -g greetd -m 750 "$state"

if [ -f /etc/greetd/config.toml ] && ! cmp -s /etc/greetd/config.toml "$here/greetd.toml"; then
    sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
fi
sudo install -m 644 "$here/greetd.toml" /etc/greetd/config.toml

sudo systemctl disable getty@tty1.service
sudo systemctl enable greetd.service
echo "Done. It takes over tty1 at the next boot. Don't start greetd from a running"
echo "session on tty1. If it doesn't come up: Ctrl+Alt+F2, log in, $0 --remove"
