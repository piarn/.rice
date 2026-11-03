# shellcheck shell=sh
# Sourced by the login shell (see ~/.dotfiles, bash/.bash_profile): tty1 starts
# sway, through sway-session (GPU choice on NVIDIA, a log, a safe-mode retry).
# Under a display manager there's no tty1 login, so this does nothing.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ] && command -v sway >/dev/null 2>&1; then
    export XDG_CURRENT_DESKTOP=sway
    # plain sway if a pull brought this file before install.sh linked the launcher
    [ ! -x "$HOME/.local/bin/sway-session" ] || exec "$HOME/.local/bin/sway-session"
    exec sway
fi
