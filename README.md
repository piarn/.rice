# ~/.rice

The sway desktop on top of `~/.dotfiles`: sway, quickshell, foot, swaylock, and
Catppuccin Mocha (mauve accent). Linux only. Terminal theming and tools live in
`~/.dotfiles`, so they follow you to any desktop.

```
git clone <dotfiles> ~/.dotfiles
git clone <rice> ~/.rice
~/.dotfiles/install.sh desktop
```

`~/.rice/install.sh` on its own takes `--link`, `--apps`, `--no-sudo` and `--dry-run`.
Each directory in its `PACKAGES` mirrors `$HOME`, and its files are linked there.
`quickshell/` is the shell, ported from
[piarn/.rice](https://github.com/piarn/.rice) at `4156a09`, its last styled
version, without the theme switcher (its greetd login screen is redone in `greeter/`): a centered
island that grows into tabs (system, calendar, notifications, network, run,
clipboard), toasts, OSD and lock screen, with its helpers in `.local/bin`.
`$mod+d` opens the launcher; `=` `>` `/` `?` `@` `~` `!` `:` as the first
character switch its mode. For weather, set `city=<name>` in
`~/.config/dots/weather.conf`.
`swaylock` remains the fallback when quickshell's lock screen doesn't come up.

## Keys

`$mod`+letter is the everyday action, `$mod+Shift` the bigger version.

| Keys | Action |
| --- | --- |
| `$mod+Return` / `$mod+Shift+Return` | terminal with ligatures (`foot-lig`) / stock foot |
| `$mod+Space`, `$mod+d` | launcher |
| `$mod+q` | close window |
| `$mod+e` / `$mod+b` | files (yazi) / browser (LibreWolf) |
| `$mod+v` | clipboard history |
| `$mod+n` / `$mod+Shift+n` | network tab / system tab |
| `$mod+Escape` | lock |
| `$mod+Shift+Escape` | session menu: lock, reload, suspend, logout, reboot, shutdown |
| `$mod+h/j/k/l`, arrows | focus; add Shift to move the window |
| `$mod+1`–`0` | workspace; add Shift to send the window there |
| `$mod+t` | flip the split direction |
| `$mod+w` / `$mod+Shift+w` | toggle tabbed and tiled / wrap in a tabbed group |
| `$mod+f` / `$mod+Shift+f` | maximize / fullscreen |
| `$mod+Shift+t` | toggle floating |
| `$mod+Tab` | focus between tiled and floating |
| `$mod+a` | focus parent |
| `$mod+r` | resize mode |
| `$mod+minus` / `$mod+Shift+minus` | show / send to scratchpad |
| `$mod+Shift+s`, `Shift+Print` | region screenshot to the clipboard |
| `Print` | full screenshot to the clipboard |
| `$mod+Shift+c` | reload sway and restart quickshell |

`packages.tsv` lists what the desktop needs on each package manager. On Gentoo it
becomes the `@rice` set, with `portage/` holding its keywords, USE flags and the
overlay's file picker ebuild. `net-vpn/netbird-bin` stays out of both repos on purpose.

## Platforms

Tested in containers on 2026-11-01, on Quickshell 0.3.2: it compiled from source, then
loaded this repo's real config under a headless sway. No real screen or hardware was
involved, so a running desktop has only been seen on this ThinkPad.

| Distro | Quickshell | Other gaps |
| --- | --- | --- |
| Gentoo | Compiled by its ebuild (guru) | None |
| Arch, Fedora, openSUSE Tumbleweed, Ubuntu 26.04, Debian 13 | Compiled, config loads | No termfilechooser, so GTK file dialogs |
| Ubuntu 24.04, Debian 12 | **Refused: Qt 6.4 is older than the 6.6 it needs** | No launcher, bar, notifications or quickshell lock screen; use the terminal profile or upgrade |
| macOS, WSL | Refused | This is a Wayland desktop; use the terminal profile |

Everywhere but Gentoo, `build-quickshell.sh` builds it, pinned by version and hash, into
`~/.local/opt/quickshell`. The first build takes several minutes and pulls in Qt's
development packages. It leaves out Hyprland, X11 and the crash handler: `qs-watchdog`
restarts quickshell instead, and Gentoo's build still has its crash handler.

Quickshell uses Qt's private APIs, so it has to be rebuilt whenever Qt changes. `dots
upgrade` does this for you. **If you update with `dnf`, `apt` or `pacman` directly, run
`~/.rice/build-quickshell.sh --if-stale` afterwards**, or quickshell may crash.

### VPNs

The network tab toggles Tailscale, NetBird and Mullvad, whichever are installed, and
only one is up at a time: turning one on first turns the others off, because two
tunnels fight over routes and firewalls. A new VPN is one `extras/<name>/Vpn.qml` that
sets `upCommand` and `downCommand`, and it follows the same rule.

- **Mullvad:** only its daemon and CLI are used. On Gentoo `install.sh` installs
  `net-vpn/mullvad-cli` from this repo's overlay: the official RPM without the app.
  Elsewhere Mullvad's own package from [its repository](https://mullvad.net/en/download/vpn/linux)
  includes the app. On Fedora, `system/rpm-macros.mullvad-cli` makes rpm skip the app's
  files on every install and upgrade (`%_netsharedpath`), keeping only the daemon and
  CLI; install it before Mullvad, or reinstall Mullvad after it:

  ```
  sudo install -m644 ~/.rice/system/rpm-macros.mullvad-cli /etc/rpm/macros.mullvad-cli
  sudo dnf reinstall mullvad-vpn
  ```

  Either way the daemon needs enabling once, and the login has to wait until the
  daemon answers:

  ```
  sudo systemctl enable --now mullvad-daemon
  until mullvad status >/dev/null 2>&1; do sleep 0.5; done; mullvad account login
  ```
- **Tailscale:** `sudo tailscale set --operator=$USER` once, so the toggle needs no sudo.

### NVIDIA

The tty1 login starts sway through `sway-session`, which logs to `~/.local/state/sway.log`.
If sway dies within 10 seconds, it retries once with the distro's stock config. With
NVIDIA's own driver loaded, `sway-session` also does the following:

- **Adds `--unsupported-gpu`,** which sway refuses to start without.
- **Uses one GPU per session:** NVIDIA when a display is plugged into one of its ports,
  the integrated GPU otherwise. Mixing the two blacks out the laptop panel. Plugging a
  display into an NVIDIA port mid-session needs a new login.
- **Uses the Vulkan renderer on NVIDIA,** or screen sharing fails in Discord and browsers.
- **Draws the cursor in software,** or it garbles canvas and WebGL content beneath it.

Sway older than 1.12 makes parts of the screen flicker on NVIDIA. On Fedora 44, which
ships 1.11, `install.sh` runs `build-sway.sh` to rebuild Fedora's own 1.12 package. On
other distros it only warns.

**Video on Fedora:** Fedora's own ffmpeg can only pass H.264 to OpenH264, which plays
just its simplest profile, so most videos (screen captures included) won't play in mpv
and get no preview in yazi. RPM Fusion's ffmpeg has the codecs:

```
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf swap ffmpeg-free ffmpeg --allowerasing
```

The driver itself is not installed by `install.sh`. On Fedora it's `akmod-nvidia` from
RPM Fusion, and with Secure Boot on, its signing key has to be enrolled. A display
manager's Sway entry runs plain `sway` and fails on NVIDIA, so disable the display
manager (`systemctl disable gdm`) and log in on tty1. `sway-session --dry-run` prints
the GPU and settings it would use.

The versions of everything else here come from the distro, except `foot-lig` and the
Material Symbols and Nerd Font icons, which are pinned. Only `~/.dotfiles`'s terminal
tools are pinned across systems.

## Decisions

| Decision | Where it's captured |
| --- | --- |
| LibreWolf as the native browser, default for links and PDFs | `packages.tsv`, `set_default_apps` in `install.sh` |
| LibreWolf keeps your real time zone, keeping `+AllTargets` fingerprinting protection | `librewolf/user.js`, linked into every profile |
| Apps told the desktop is dark, so Flatpaks follow it | `setup_appearance` in `install.sh` |
| Yazi as the file picker | `portal/`, `system/sway-portals.conf`, `portage/overlay` |
| mpv, imv and yazi with poppler for media and PDFs | Manifests; imv built with GIF, WebP and SVG |
| Flatpak for LibreOffice, Thunderbird ESR, Discord and Prism | `apps.txt`, opt-in with `--apps` |
| LibreOffice can't read your home folder | `--nofilesystem=host` in `apps.txt` |
| SSH by key only, inbound firewall default-drop | `system/10-hardening.conf`, `system/nftables.nft` |
| Quickshell handles notifications and brightness: no mako, wmenu or light | Not in `packages.tsv` |

Recorded by hand, because they hold private details or can't be scripted:

- **Thunderbird:** only the main account notifies. On each alias account, under Account
  Settings → Server Settings, turn off checking at startup, checking every N minutes and
  immediate notifications. The aliases still appear under **From**, and their mail only
  arrives when you open that inbox or click Get Messages.
- **LibreWolf:** the `Provly` bookmarks live in the work profile, kept apart from
  everyday browsing. Reinstall the extensions per profile: Bitwarden, uBlock Origin.

`system/` is applied only by running `system/apply.sh`, which asks first. Don't use it on
a managed machine. `system/gentoo-thinkpad/` is a snapshot of this laptop's Portage config,
world file, kernel firmware choice and power scripts, for rebuilding it. Nothing reads it.

### File picker elsewhere

Gentoo gets `xdg-desktop-portal-termfilechooser` from the overlay. On Arch use
`xdg-desktop-portal-termfilechooser-hunkyburrito-git` from the AUR. Anywhere else, build
tag `v1.5.0` of [the project](https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser)
with meson and run `install.sh` again. Until then, the installer leaves the setting out,
because asking the portal for a missing backend makes every file dialog fail.

## Not done yet

- **Backups:** nothing leaves the laptop. Planned for mid-November 2026: a Hetzner
  server as the restic target, once there's budget.
- **SSH keys:** all four in `~/.ssh/keys` still have no passphrase.
- **sshd:** still enabled, with no `authorized_keys`, so it can't be logged in to. Add a
  key or disable it.
- **Flatpak Firefox:** still installed. Remove it once nothing is left in that profile.
- **Suggested, not decided:** `sys-apps/fwupd`, `app-arch/7zip`, `media-fonts/noto-cjk`,
  a monthly `btrfs scrub`, Xwayland for X11-only games.

The tmux bar centers its window list, and the shell and session sections have
icons from Symbols Nerd Font, foot's fallback font. Window 10 shows as `0` to
match the number row, and the number keys in TMUX mode select windows the same
way: `1`–`9`, then `0` for window 10.

## Login screen

`greeter/` is a greetd greeter in the lock screen's look: the clock, a user line, the
password cells, and the session. greetd runs it as its own user in a throwaway sway, so
`greeter/install.sh` copies it and the components it uses to `/etc/greetd/quickshell/`
(standalone; rerun it after changing them), installs `/etc/greetd/config.toml`, and
swaps the tty1 login for greetd from the next boot. It remembers the last user and
session in `/var/lib/qs-greeter/last`, and starts the session through `bash -l`, like the
tty1 login: sway goes through `sway-session`.

| Keys | Action |
| --- | --- |
| `Tab` / `Enter` | user ↔ password / next field, then log in |
| `F1` / `F2` | power off / reboot |
| `F3`, `Ctrl+←/→` | session |

Needs `gui-libs/greetd` (Gentoo) or `greetd greetd-selinux` (Fedora). Where quickshell
is built into `~/.local/opt`, it copies it to `/usr/local/bin/quickshell` (which
`build-quickshell.sh` keeps current), plus Departure Mono from `~/.local/share/fonts`, since
the greetd user can't read your home; with SELinux on, it labels `/var/lib/qs-greeter`
`xdm_var_lib_t`. `install.sh --stage DIR` only assembles the config, for
a preview (`QML2_IMPORT_PATH=DIR/theme qs -p DIR`, `Esc` quits). If it doesn't come up,
`Ctrl+Alt+F2`, log in, and `greeter/install.sh --remove` brings back the tty1 login.

## Foot with ligatures

`foot-lig` is the default terminal: sway's `$term`, the launcher, the network tab
and `tmux-open` all use it. It runs a patched foot 1.24.0 from
`~/.local/opt/foot-ligatures`, linked against its own patched fcft, and opens
stock foot instead if that build is missing or won't run. `/usr/bin/foot` and the
system fcft are untouched, and no package manager knows about this build.

The build has its own project, `~/projects/foot-lig`, with pinned sources and patches:

```sh
cd ~/projects/foot-lig
./build.sh --deps
```

`install.sh` doesn't build it, so a fresh install runs stock foot until you do. Run
`./build.sh` again if a harfbuzz or utf8proc upgrade breaks it. Measurements are in that
project's README.

To remove it, run `./build.sh --uninstall`, delete `foot-ligatures.ini` with its link, point
`$term` in the sway config, `term` in `RunSection.qml`, `openEditor` in `NetworkState.qml` and
`tmux-open` back at `foot`, then delete `foot-lig` with its link.
