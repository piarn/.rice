# .rice

The desktop: sway, quickshell (status bar, launcher, lock screen, login
screen), kitty/foot and the session around them. Installed only on
machines using [`~/.dots`](https://github.com/piarn/.dotfiles)' **desktop**
profile: `~/.dots/install.sh desktop` installs the terminal profile and
then runs this repo's `install.sh` on top. A work laptop on the
**terminal** profile never needs this repo.

Looks are deliberately plain and fixed: one black/gray palette (no theme
switching), no gaps, 1px borders, no titlebars, no wallpaper.

```
~/.rice/install.sh              install / re-link the desktop (after ~/.dots)
~/.rice/install.sh --doctor     read-only check (also run by ~/.dots/install.sh --doctor)
~/.rice/install.sh --uninstall  unlink the desktop configs (~/.dots/install.sh terminal does this)
~/.rice/tests/run.sh            the desktop scripts' tests
```

`desktop/` holds one stow package per app (`sway`, `quickshell`, `kitty`,
`foot`, `satty`, `firefox`, `hidden-apps`, `scripts`), each mirroring
`$HOME`; the palette is written straight into each app's config (sway's
`theme.conf`, quickshell's `theme/quickshell/Colors.qml`, kitty.conf,
foot.ini). The packages are in `.bootstrap/`; the only flatpaks are
Firefox and Prism Launcher. `layouts/` and `bin/apply-layout` are the
screen layouts (below).

## Boot and login

What makes the machine come up usable after a boot, all installed by
`install.sh` (system files, so it asks for sudo) and checked by
`--doctor`'s "boot" section:

- **greetd** owns tty1 (ly and `getty@tty1` are disabled). Its greeter,
  `/usr/local/bin/dots-greeter`, runs the **quickshell login screen** —
  `greeter.qml` in the quickshell config, built from the lock screen's own
  face, so logging in and unlocking look the same — in a bare sway, as the
  `greetd` user.
- Type the password and Enter; **Tab** switches between the **sway**
  session and **terminal** (a plain login shell, for when the desktop is
  what's broken or isn't wanted). The choice is remembered.
- The greeter can't read `$HOME`, so it runs quickshell from
  `/usr/local/libexec/dots-greeter/` and its QML, palette, screen layout and
  keyboard from `/var/lib/dots-greeter/`. That directory is yours:
  `greeter-sync` refreshes it without sudo, and `rice-reload` runs it
  whenever quickshell is reloaded.
- If the login screen doesn't work out — sway or quickshell fails, it
  isn't up within 15s, or you press **Ctrl+Alt+Backspace** — greetd's text
  login (`agreety`) takes over on tty1, starting sway after the password.
  Ctrl+Alt+F2 and up still give a plain text login (logind's autovt).
- Both the greeter and the sway session start through
  `/usr/local/bin/sway-session` (from `.bootstrap/`): one GPU per session
  on the hybrid NVIDIA laptop and a log in `~/.local/state/sway.log`; for
  the desktop also a safe-mode retry with the stock config when sway dies
  within 10s.
- Inside sway, the session services start under `dots-session.target`
  once sway has exported its environment, and are restarted if they die;
  quickshell is watched by `qs-watchdog`.

## Desktop

sway + [quickshell](desktop/quickshell/.config/quickshell): a thin
full-width **bar** at the top of each screen — workspaces on the left,
time and date in the middle, and on the right recording, "silenced",
network, volume and battery as plain text (click network for `nmtui`,
volume to mute, scroll it to change it) — plus the **launcher**, the lock
screen and notification toasts. The rule for keys: `$mod`+letter is the
everyday action, `$mod+Shift` is the bigger version (move, capture,
system). Plain Alt is left to apps.

| Keys | Action |
| --- | --- |
| `$mod+Return` / `$mod+Shift+Return` | terminal (kitty) / quick terminal (foot) |
| `$mod+Space` / `$mod+d` | launcher |
| `$mod+q` | close window |
| `$mod+v` | clipboard history (`clip-pick`: cliphist in fzf, floating) |
| `$mod+n` | network (`nmtui`, floating) |
| `$mod+e` | files (yazi, in kitty) |
| `$mod+b` | browser (Firefox) |
| `$mod+h/j/k/l`, arrows | focus; add Shift to move the window |
| `$mod+1`–`0` | workspace; add Shift to send the window there |
| `$mod+t` | toggle split direction (side by side ↔ stacked) |
| `$mod+w` | toggle tabbed ↔ tiled |
| `$mod+f` / `$mod+Shift+f` | maximize / fullscreen |
| `$mod+Shift+t` | toggle floating |
| `$mod+Tab` | focus between tiled and floating windows |
| `$mod+a` | focus parent container |
| `$mod+r` | resize mode (hjkl/arrows, Enter or Esc to leave) |
| `$mod+minus` / `$mod+Shift+minus` | show / send to scratchpad |
| `$mod+Shift+s` | region screenshot: frozen screen in satty, crop, Enter saves + copies |
| `$mod+Shift+r` | start/stop screen recording to `~/Videos/Captures` (click a window, drag a region, or click a monitor's bar) |
| `$mod+Escape` | lock |
| `$mod+Shift+Escape` | launcher in `:` session mode (lock, suspend, logout, reboot, shutdown) |
| `$mod+Shift+c` | reload sway and restart quickshell |

The launcher is a search box and a short list: apps, most-used first,
ranked by name/description/keywords ("browser" finds Firefox). A leading
character switches to a mode:

| Prefix | Mode |
| --- | --- |
| `=` | calculator (`=2^10*3`, `sqrt`, `pi`); Enter copies the result |
| `>` | shell command; Enter runs it in kitty, Shift+Enter in the background |
| `/` | files under `~` via fd (empty: recently opened); Shift+Enter shows it in yazi |
| `?` | web search (or open an address) |
| `@` | switch to an open window |
| `~` | dev: tmux sessions (running and frozen), git projects, ssh hosts from `~/.ssh/config`; Enter opens one as a tmux session (`tmux-open`) in the terminal already showing tmux, or a new kitty |
| `!` | tools: region screenshot, screen recording, color picker (`color-pick`), clipboard history, silence |
| `:` | session: lock, reload, suspend, logout, reboot, shutdown (the last three need Enter twice); `:layout <name>` |

Keys: ↑↓ or `^j`/`^k` move, Enter acts, Esc or a click outside closes.
`qs ipc call commandcenter toggle` opens/closes it; `commandcenter open
'<text>'` opens it pre-typed, e.g. `'@'` for the window switcher.

Background services run as systemd user services under
`dots-session.target` (`desktop/sway/.config/systemd/user`), started once
sway has exported its environment and stopped when it exits: the polkit
agent (`mate-polkit`, password prompts), swayidle (lock after 10 minutes
idle and before sleep), cliphist, udiskie, the bluetooth agent,
`layout-watch` and `qs-watchdog`. A dead one is restarted;
`journalctl --user -u <name>` has its log, and `~/.dots/install.sh
--doctor` flags any that aren't running.

If quickshell hangs or crashes, `qs-watchdog` restarts it within ~15s
(re-locking if the session was locked) and keeps a hung instance's log
under `~/.cache/qs-watchdog/`. `$mod+Shift+c` does the same by hand.

New files in a package need `stow -R --no-folding -d ~/.rice/desktop -t ~ <pkg>`
before they're linked in — quickshell reports a new QML file as "X is not a
type" until then.

## Screen layouts

`layouts/` has one sway `output` profile per physical setup (`laptop`,
`home-office`, `docked`, `extend`, `present`), each naming the outputs it
needs in a `# requires:` comment (connector names, or `"make model
serial"` for externals, which survive reconnects). `bin/apply-layout
<name>` switches; `apply-layout --auto` picks the most specific profile
whose outputs are all connected, and `layout-watch` runs that on every
dock/undock. The launcher's `:layout <name>` does the same. The active
one renders to `sway/outputs.conf` (per machine, untracked).

### When things break

- **quickshell's config doesn't load:** `qs-watchdog` runs the last config
  that did (`~/.local/state/dots/quickshell-good`) and says so in a
  swaynag. Fix the config and run `dots-reload quickshell`; once it loads,
  the fallback is stopped.
- **Locking:** everything locks through `dots-lock`, which uses swaylock
  when quickshell's lock screen doesn't come up.
- **sway dies at startup:** `sway-session` retries once with the stock
  `/etc/sway/config` (safe mode); see `~/.local/state/sway.log`. If that
  fails too you're back at the login screen: Tab to the **terminal**
  session there for a plain shell.
  `dots-reload` won't reload a sway config that fails `sway -C`.
- **The session is wedged:** switch to a TTY (Ctrl+Alt+F3) or ssh in and
  run `dots-rescue` for the options (restart or roll back quickshell,
  reload or exit sway, get a swaylock prompt).
