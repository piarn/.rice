#!/usr/bin/env bash
# Rebuilds Fedora's own sway 1.12 package on Fedora 44, which ships 1.11. Only
# install.sh's NVIDIA step runs it: sway before 1.12 aborts in its explicit-sync
# code, sway-session turns that off for it, and on NVIDIA's driver that makes parts
# of the screen flicker or show stale frames.
#
# Fedora 45's packaging builds as it is on 44, which already has the wlroots 0.20
# it needs. It's pinned to one dist-git commit, and the source tarball is checked
# against that commit's hashes. Only the sway packages already installed get
# replaced, and a later Fedora update to 1.12 or newer replaces this build.
#
#   ./build-sway.sh            build and install (sudo)
#   ./build-sway.sh --check    exit 0 if sway is already 1.12 or newer
set -euo pipefail

MIN_VERSION=1.12
DISTGIT=https://src.fedoraproject.org/rpms/sway.git
COMMIT=53c4dd8b23da0497025e3f49c1ca7724b721f34f # f45: "Update to 1.12", mass rebuild

say() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

# From the package database where there is one: running sway can fail where its
# file capabilities aren't allowed (rootless containers).
installed_version() {
    rpm -q --qf '%{VERSION}' sway 2>/dev/null || sway --version 2>/dev/null | awk '{print $3}'
}

current() {
    local v
    v=$(installed_version) || true
    [ -n "$v" ] && [ "$(printf '%s\n' "$MIN_VERSION" "$v" | sort -V | head -n1)" = "$MIN_VERSION" ]
}

case ${1:-} in
    --check) current; exit ;;
    '') ;;
    *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

current && exit 0
command -v dnf >/dev/null 2>&1 || die "this rebuilds Fedora's package; on this distro install sway $MIN_VERSION or newer from its own packages"

say "building sway $MIN_VERSION from Fedora's packaging (a few minutes)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q "$DISTGIT" "$tmp/sway"
git -C "$tmp/sway" checkout -q "$COMMIT"
(
    cd "$tmp/sway"
    as_root dnf install -y -q rpm-build 'dnf-command(builddep)'
    as_root dnf builddep -y -q sway.spec
    # each line: SHA512 (file) = hash
    while read -r _ file _ hash; do
        file=${file#(} file=${file%)}
        curl -fsSL -o "$file" "https://src.fedoraproject.org/repo/pkgs/rpms/sway/$file/sha512/$hash/$file"
    done <sources
    sha512sum -c --quiet sources
    rpmbuild -bb --quiet --define "_topdir $tmp/rpmbuild" --define "_sourcedir $PWD" sway.spec
)
pkgs=()
for rpm in "$tmp"/rpmbuild/RPMS/*/*.rpm; do
    rpm -q "$(rpm -qp --qf '%{NAME}' "$rpm" 2>/dev/null)" >/dev/null 2>&1 && pkgs+=("$rpm")
done
[ ${#pkgs[@]} -gt 0 ] || die "the build made no package that replaces an installed one"
as_root dnf install -y -q "${pkgs[@]}"
say "sway $(installed_version) installed; log in again to use it"
