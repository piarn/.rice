#!/usr/bin/env bash
# The system-wide decisions: SSH keys only, default-drop firewall. Never run by
# install.sh, and not for a managed machine, whose admins own these. Shows what it
# will do and asks first. Run it from a machine you can reach physically.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This will, with sudo:"
echo "  - install 10-hardening.conf to /etc/ssh/sshd_config.d/ (key login only)"
echo "  - load nftables.nft and make it persist (drop inbound except SSH from HOME_LAN)"
printf 'Continue? [y/N] '
read -r reply
case $reply in y | Y) ;; *) echo "Nothing changed."; exit 0 ;; esac

if [ -d /etc/ssh/sshd_config.d ]; then
    sudo install -m644 "$here/10-hardening.conf" /etc/ssh/sshd_config.d/10-hardening.conf
    if sudo sshd -t; then
        sudo systemctl reload sshd 2>/dev/null || sudo systemctl reload ssh 2>/dev/null || true
    else
        sudo rm -f /etc/ssh/sshd_config.d/10-hardening.conf
        echo "error: sshd rejected the config; removed it again" >&2
        exit 1
    fi
fi

if command -v nft >/dev/null 2>&1; then
    sudo nft -c -f "$here/nftables.nft"
    sudo nft -f "$here/nftables.nft"
    if [ -e /usr/libexec/nftables/nftables.sh ]; then
        # Gentoo: nftables-load restores this file at boot
        sudo sh -c 'nft list table inet filter > /var/lib/nftables/rules-save'
        sudo systemctl enable nftables-load
    else
        sudo install -m644 "$here/nftables.nft" /etc/nftables.conf
        sudo systemctl enable nftables 2>/dev/null || true
    fi
else
    echo "warning: nft isn't installed; firewall skipped" >&2
fi
echo "Done."
