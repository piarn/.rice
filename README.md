# .rice

The desktop, and the palette everything is drawn in.

- **Desktop** (`desktop/`, `install.sh`): sway + quickshell, the GUI apps
  and the session around them. Installed only on machines using
  [`~/.dots`](https://github.com/piarn/.dotfiles)' **desktop** profile:
  `~/.dots/install.sh desktop` installs the terminal profile and then runs
  this repo's `install.sh` on top. A work laptop on the **terminal**
  profile never links or installs any of it.
- **Theming** (`themes/`, `templates/`, `bin/apply-theme`): the palette
  lives in one file and every app's colors are generated from it — the
  terminal tools' too, so both profiles clone this repo and render the
  current theme.

```
~/.rice/install.sh              install / re-link the desktop (after ~/.dots)
~/.rice/install.sh --doctor     read-only check (also run by ~/.dots/install.sh --doctor)
~/.rice/install.sh --uninstall  unlink the desktop configs (~/.dots/install.sh terminal does this)
~/.rice/tests/run.sh            the desktop scripts' and island's tests
```

`desktop/` holds one stow package per app (`sway`, `quickshell`, `kitty`,
`foot`, `satty`, `kde`, `firefox`, `hidden-apps`, `scripts`), each mirroring
`$HOME`; `desktop/extras/<name>` (none right now) is where the desktop
half of a `~/.dots` extra goes, linked by `extras.sh` on the desktop profile.
The packages and flatpaks are in `.bootstrap/`.

## Boot and login

What makes the machine come up usable after a boot, all installed by
`install.sh` (system files, so it asks for sudo) and checked by
`--doctor`'s "boot" section:

- **ly** (`ly@tty1`), the TUI login manager, owns tty1 alone —
  `getty@tty1` is disabled so the two never contend for it. Ctrl+Alt+F2 and
  up still give a plain text login (logind's autovt).
- ly lists only `/usr/local/share/wayland-sessions`, whose **Sway** entry
  runs `/usr/local/bin/sway-session` (from `.bootstrap/`): one GPU per
  session on the hybrid NVIDIA laptop, a log at `~/.local/state/sway.log`
  (the previous one kept as `sway.log.old`), and a safe-mode retry with
  the stock config when sway dies within 10s. The distro's own entry runs a
  bare `sway` that skips all of that, so it isn't offered.
- ly also offers a **Terminal** session (`/etc/ly/custom-sessions/terminal.desktop`):
  a login shell and nothing else — tmux, nvim and the agent pool all work
  from it — for when the desktop is what's broken, or isn't wanted.
- Inside sway, the session services start under `dots-session.target`
  once sway has exported its environment, and are restarted if they die;
  quickshell is watched by `qs-watchdog`.

## Desktop

sway + [quickshell](desktop/quickshell/.config/quickshell): one 600px **island**
centered at the top of each screen (workspaces · clock · status) that grows
into tabs — system, calendar, notifications, network, run (the command
center) and clipboard — plus the lock screen and notification toasts.
Click the clock for the calendar, the status for system, `●` for
notifications; inside, `h`/`l` or Ctrl+Tab switch tabs, Esc or a click
outside collapses it. The rule: `$mod`+letter is
the everyday action, `$mod+Shift` is the bigger version (move, capture,
system). Plain Alt is left to apps.

Weather (the bar's clock pill and the lock screen) is for one fixed city,
set per machine and kept out of the repo:
`echo city=Vilnius > ~/.config/dots/weather.conf`. `dots-weather.timer`
fetches it from Open-Meteo every 30 minutes; without that file it stays
hidden.

| Keys | Action |
| --- | --- |
| `$mod+Return` / `$mod+Shift+Return` | terminal (kitty) / quick terminal (foot) |
| `$mod+Space` / `$mod+d` | the island's run tab, the command center (either key) |
| `$mod+q` | close window |
| `$mod+v` | the island's clipboard tab (cliphist history) |
| `$mod+e` | file manager (Dolphin) |
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
| `$mod+Shift+Escape` | command center: `:` session mode (lock, suspend, logout, reboot, shutdown) |
| `$mod+Shift+c` | reload sway and restart quickshell |

The command center is a search box and a short list: apps, most-used
first, ranked by name/description/keywords ("pdf" finds Zathura). A
leading character switches to a mode:

| Prefix | Mode |
| --- | --- |
| `=` | calculator (`=2^10*3`, `sqrt`, `pi`); Enter copies the result |
| `>` | shell command; Enter runs it in kitty, Shift+Enter in the background |
| `/` | files under `~` via fd (empty: recently opened); Shift+Enter shows it in Dolphin |
| `?` | web search (or open an address) |
| `@` | switch to an open window |
| `~` | dev: tmux sessions (running and frozen), git projects, ssh hosts from `~/.ssh/config`; Enter opens one as a tmux session (`tmux-open`) in the terminal already showing tmux, or a new kitty |
| `!` | tools: region screenshot, screen recording, color picker (`color-pick`), clipboard history, notifications, silence |
| `:` | session: lock, reload, suspend, logout, reboot, shutdown (the last three need Enter twice); `:theme <name>`, `:layout <name>` |

Keys: ↑↓ or `^j`/`^k` move, Enter acts, Esc closes. The mouse works
everywhere too.

`qs ipc call commandcenter toggle` opens/closes it; `commandcenter open
'<text>'` opens it pre-typed, e.g. `'@'` to bind a key straight to the
window switcher, or `':'` straight to session actions.

The command center is the island's run tab. The system tab is the
mouse-first glance of the same things (plus the tray, media and battery),
and the other tabs hold the deep views (enterprise/hidden Wi-Fi, VPN
details, calendar, notifications).

Background services run as systemd user services under
`dots-session.target` (`desktop/sway/.config/systemd/user`), started once sway has
exported its environment and stopped when it exits: the polkit agent
(`mate-polkit`, password prompts), swayidle (lock after 10 minutes idle and
before sleep), cliphist, udiskie, the bluetooth agent, `layout-watch` and
`qs-watchdog`. A dead one is restarted; `journalctl --user -u <name>` has
its log, and `~/.dots/install.sh --doctor` flags any that aren't running.

If quickshell hangs or crashes, `qs-watchdog` restarts it within ~15s
(re-locking if the session was locked) and keeps a hung instance's log
under `~/.cache/qs-watchdog/`. `$mod+Shift+c` does the same by hand.

New files in a package need `stow -R --no-folding -d ~/.rice/desktop -t ~ <pkg>`
before they're linked in — quickshell reports a new QML file as "X is not a
type" until then.

### When things break

- **quickshell's config doesn't load:** `qs-watchdog` runs the last config
  that did (`~/.local/state/dots/quickshell-good`) and says so in a
  swaynag. Fix the config and run `dots-reload quickshell`; once it loads,
  the fallback is stopped.
- **Locking:** everything locks through `dots-lock`, which uses swaylock
  when quickshell's lock screen doesn't come up.
- **sway dies at startup:** `sway-session` retries once with the stock
  `/etc/sway/config` (safe mode); see `~/.local/state/sway.log`. If that
  fails too you're back at the login screen: pick the **Terminal**
  session there (F-keys / arrows in ly) for a plain shell.
  `dots-reload` won't reload a sway config that fails `sway -C`.
- **The session is wedged:** switch to a TTY (Ctrl+Alt+F3) or ssh in and
  run `dots-rescue` for the options (restart or roll back quickshell,
  reload or exit sway, get a swaylock prompt).

# Theming

## Changing/switching the theme

```
~/.rice/bin/apply-theme            # re-render the current theme (after editing it)
~/.rice/bin/apply-theme <name>     # switch to ~/.rice/themes/<name>/theme.toml and render it
~/.rice/bin/apply-theme <name> --dry-run   # show what would change, write nothing
```

Edit a color in `~/.rice/themes/<name>/theme.toml`, run `apply-theme`, and
every app's theme file under `~/.rice/<app>/...` gets re-rendered from
`~/.rice/templates/<app>/*.tmpl`. `~/.rice/themes/current` remembers which
theme is active.

Each theme is a directory, `~/.rice/themes/<name>/`, holding:
- `theme.toml` — the `[colors]` table templates render from
- `wallpaper.<ext>` — optional; copied verbatim to `~/.rice/wallpaper.png`
  (the fixed path `~/.config/sway/config` points at) and pushed live to
  every output via `swaymsg` if sway is running. A theme with no wallpaper
  file just leaves the current one in place (with a warning).

To add a new theme: copy `themes/toxic/` to `themes/<name>/`, change the
`[colors]` values in `theme.toml` (and swap in a `wallpaper.<ext>` if you
have one), then `apply-theme <name>`. Templates reference colors by role
(`neon`, `dim`, `red`, ...), not by value, so any theme that defines the
same roles drops in without touching a single app config.

## Themes

**Toxic** — black & toxic-waste-green.

| Role              | Hex       |
|-------------------|-----------|
| Black (bg)        | `#000000` |
| Foreground        | `#D9FFD9` |
| Neon green (accent) | `#39FF14` |
| Acid green (bright)  | `#ADFF2F` |
| Dim green (muted)    | `#1F4D0F` |
| Deep green (inactive) | `#143D0A` |
| Gray (inactive text) | `#4D4D4D` / `#6C6C6C` |
| Red (urgent/error)   | `#FF3B30` |
| Amber                | `#CCFF00` |
| Blue                 | `#00BFFF` |
| Magenta              | `#FF3FD0` |
| Cyan                 | `#00E6B8` |

**Forest Night** — deep woodland black-green, moonlit mint highlights.

| Role              | Hex       |
|-------------------|-----------|
| Black (bg)        | `#060B07` |
| Foreground        | `#D6F2DC` |
| Green (accent)     | `#2F6B44` |
| Green (bright)     | `#4BAB6D` |
| Dim green (muted)  | `#1F3725` |
| Deep green (inactive) | `#18291C` |
| Gray (inactive text) | `#4B584E` / `#6A7C6E` |
| Red (urgent/error)   | `#E0605A` |
| Amber                | `#E0B84F` |
| Blue                 | `#4FA8D8` |
| Magenta              | `#C77DD1` |
| Cyan                 | `#4FD8B0` |

**Ember** — warm charcoal & glowing copper. Built for readability: a soft
off-black base (never pure black) and warm off-white foreground (never
pure white), accent in copper/amber territory rather than the blue/pastel
of themes like Catppuccin Mocha.

| Role              | Hex       |
|-------------------|-----------|
| Black (bg)        | `#1A1512` |
| Foreground        | `#E8DDD0` |
| Copper (accent)    | `#D98A4F` |
| Gold (bright)      | `#F0B660` |
| Dim brown (muted)  | `#4A3B2E` |
| Deep brown (inactive) | `#332922` |
| Gray (inactive text) | `#6B6058` / `#8A7F74` |
| Red (urgent/error)   | `#D9695A` |
| Amber                | `#E0A640` |
| Blue                 | `#6FA8C9` |
| Magenta              | `#C17BA5` |
| Cyan                 | `#5FADA0` |

**Nightshade** — deep violet & moonlit plum. Cool counterpart to Ember;
the violet accent and the pink magenta status color are kept a deliberate
hue-distance apart so neither reads as the other.

| Role              | Hex       |
|-------------------|-----------|
| Black (bg)        | `#120A17` |
| Foreground        | `#ECE3F0` |
| Violet (accent)    | `#8A4FD9` |
| Violet (bright)    | `#B57AF0` |
| Dim plum (muted)   | `#3A2447` |
| Deep plum (inactive) | `#291A33` |
| Gray (inactive text) | `#5E5266` / `#7D7186` |
| Red (urgent/error)   | `#D95A6E` |
| Amber                | `#D9A24F` |
| Blue                 | `#4F8FD9` |
| Magenta              | `#D94FC1` |
| Cyan                 | `#4FD9C7` |

**Monochrome** — near-grayscale with a single champagne-gold accent.
Lowest-eye-strain theme in the set: almost everything is neutral gray, and
only the accent (focused window, active prompt, current line) is allowed
to draw the eye. Status colors stay in their usual hues, just desaturated,
so diffs/git output stay legible.

| Role              | Hex       |
|-------------------|-----------|
| Black (bg)        | `#121212` |
| Foreground        | `#E4E4E4` |
| Gold (accent)      | `#D9C98F` |
| Gold (bright)      | `#F0E3B8` |
| Dim gray (muted)   | `#3A3A3A` |
| Deep gray (inactive) | `#262626` |
| Gray (inactive text) | `#6B6B6B` / `#8F8F8F` |
| Red (urgent/error)   | `#D97A7A` |
| Amber                | `#D9A44F` |
| Blue                 | `#7A9ED9` |
| Magenta              | `#B57AD9` |
| Cyan                 | `#7AD9C9` |

**Crimson** — near-black with a deep rust-red glow. The accent is pulled
toward rust/maroon rather than pure red on purpose, so "focused" and
"broken" (the error status color, pure scarlet) never share one hue.

| Role              | Hex       |
|-------------------|-----------|
| Black (bg)        | `#140808` |
| Foreground        | `#F0E0DD` |
| Rust (accent)      | `#A8313F` |
| Rust (bright)      | `#D94F5C` |
| Dim red (muted)    | `#4A1F22` |
| Deep red (inactive) | `#331519` |
| Gray (inactive text) | `#6B5452` / `#8A706D` |
| Red (urgent/error)   | `#FF4D4D` |
| Amber                | `#D9954F` |
| Blue                 | `#4F8FD9` |
| Magenta              | `#C14FA8` |
| Cyan                 | `#4FADA0` |

Full source of truth for each theme (including the bright-ANSI ramp) is
`~/.rice/themes/<name>/theme.toml`.

## How a template becomes a config file

Templates use `{{token}}` placeholders:

- `{{black}}` → `#000000` (color as `#RRGGBB`)
- `{{black.hex}}` → `000000` (no `#`, lowercase — for fish `set_color`)
- `{{black.rgb}}` → `0;0;0` (decimal, `;`-joined — for ANSI SGR strings like `EZA_COLORS`)
- `{{name}}` / `{{theme}}` → the theme's display name / file stem

`apply-theme` renders `templates/<app>/<file>.tmpl` to `<app>/<file>` for
every template it finds — e.g. `templates/eza/theme.yml.tmpl` →
`eza/theme.yml`. It refuses to render (and tells you which token) if a
template references a color the theme doesn't define.

One exception: TOML has no include directive, so `yazi/theme.toml` (this
repo) *is* consumed directly — `~/.dots/yazi/.config/yazi/theme.toml` is a
symlink straight to it, not a file that sources it.

## Apps

- `foot/` — terminal, included via `include=~/.rice/foot/theme.ini` from
  `~/.rice/desktop/foot/.config/foot/foot.ini`
- `sway/` — window border colors and gaps, included via
  `include ~/.rice/sway/theme.conf` (the status bar and launcher are
  quickshell now, not swaybar/wofi — see `quickshell/` below). `gaps
  inner/outer` in a config file only sets the default for workspaces
  created *after* a reload — already-open ones keep their old gap value
  otherwise (a sway quirk) — so `theme.conf` also carries an `exec_always`
  that replays the gap values as live `gaps ... all set N` IPC commands on
  every reload. `sway/outputs.conf` is a separate generated, per-machine (gitignored) file (not
  theme-related, see `layouts/` below), included right after it from
  `~/.config/sway/config`.
- `layouts/` — screen (output) profiles, one per physical setup, e.g.
  `home-office.conf` (docked: ultrawide + a flipped second monitor +
  laptop panel) and `laptop.conf` (undocked: laptop panel only, externals
  disabled). Each profile is plain sway `output` config plus a
  `# requires: ID-1,ID-2,...` comment naming the outputs it needs. An ID
  is a connector name (`eDP-1`, stable for a built-in panel) or a
  `"<make> <model> <serial>"` string, which sway also accepts as output
  criteria — use that for anything external, since Thunderbolt/DP-MST
  reconnects renumber connectors (DP-5 became DP-7 after one
  unplug/replug) but not make/model/serial.
  Switch with `~/.rice/bin/apply-layout <name>`, or let it auto-detect
  with `apply-layout --auto` (picks whichever profile's `requires:` set
  is fully connected, preferring the most specific match).
  `~/.rice/bin/layout-watch` is a small daemon, started via
  `exec_always` from `~/.config/sway/config`, that subscribes to sway's
  output-change events and calls `apply-layout --auto` on dock/undock; it
  takes an exclusive lock on a runtime file so re-running it on every
  config reload doesn't pile up processes. `layouts/current` remembers
  which profile is active, same pattern as `themes/current`.
- `quickshell/` — bar + the dots command center (apps, settings, themes), replacing waybar/swaybar and wofi.
  `Colors.qml` is a `pragma Singleton` QML object rendered from
  `templates/quickshell/Colors.qml.tmpl`, paired with a static (untemplated)
  `qmldir` that declares it — same "just a plain file, not rendered"
  exception as `yazi/theme.toml` below, except here it's the *loader*, not
  the theme file itself, that has no include-directive equivalent to lean
  on. `~/.rice/desktop/quickshell`'s QML (`shell.qml`, `Bar.qml`, `popups/CommandCenter.qml`)
  pulls it in via `import quickshell`, an unquoted module import resolved
  through `QML2_IMPORT_PATH=$HOME/.rice` (set inline on the `exec_always`
  in `~/.config/sway/config`) — a quoted relative import
  (`import "../../.rice/quickshell"`) does *not* work here, because
  quickshell loads each config into a virtual `qs:/` resource tree where
  `..` never escapes `~/.config/quickshell`. The bar's icon glyphs need
  `~/.local/share/fonts/MaterialSymbols` (`install.sh`'s
  `install_material_symbols`) — plain "monospace" has none of them,
  confirmed by screenshotting actual candidate codepoints rather than
  trusting a font's cmap table.
  `popups/LockScreen.qml` replaces swaylock: a `WlSessionLock`
  (`ext-session-lock-v1`, same protocol swaylock used — the compositor
  keeps the screen locked and painted solid even if quickshell crashes)
  styled straight from `Colors.qml`, authenticating via `PamContext`
  against `/etc/pam.d/quickshell-lock` (a system file `install.sh`'s
  `install_pam_lock_config` writes — not itself part of this repo).
  `~/.rice/desktop/scripts/.local/bin/lock-wallpaper` blurs a per-output
  screenshot into `$XDG_RUNTIME_DIR/quickshell-lock/` right after the lock
  engages (locking itself is instant, the blurred background fades in a
  beat later).
- `yazi/` — `theme.toml` (TOML has no include directive, so this file *is*
  the config): `~/.dots/yazi/.config/yazi/theme.toml` is a relative symlink
  straight to it, stowed to `~/.config/yazi/theme.toml`. Themes UI chrome and
  the broad filetype mime groups; leaves the per-extension icon/brand-color
  tables alone, same call as nvim's syntax highlighting
- `tmux/` — status bar / panes / messages, sourced via `source-file ~/.rice/tmux/theme.conf`
  from `~/.dots/tmux/.config/tmux/tmux.conf`
- `nvim/` — editor chrome only (statusline, splits, popups, gutter, signs —
  never Comment/String/Function/`@`-treesitter groups), loaded via
  `dofile(vim.fn.expand("~/.rice/nvim/theme.lua"))` from
  `~/.dots/nvim/.config/nvim/lua/config/theme.lua`
- `fish/` — prompt color (`rice_color_dir`), sourced via the existing
  `~/.dots/fish/.config/fish/conf.d/00-rice.fish` hook
- `eza/` — `theme.yml` (perms, size, users, git, file types, ...) pointed at
  via `EZA_CONFIG_DIR`, plus a small `EZA_COLORS` override for the ten
  classic file-kind codes (di/ln/ex/...) that `LS_COLORS` would otherwise
  clobber — both set from `~/.rice/eza/colors.fish`, sourced by
  `00-rice.fish`
- `fzf/` — `FZF_DEFAULT_OPTS` (fzf.fish's base options + `--color`), sourced
  from `00-rice.fish` before fzf.fish's own wrapper would otherwise set its
  defaults
- `lazygit/`, `lazydocker/` — partial `config.yml` (just `gui.theme`; each
  tool merges it over its own defaults). YAML has no include directive, so
  same deal as `yazi/`: `~/.dots/lazygit(.../lazydocker)/.config/.../config.yml`
  is a relative symlink straight to these files
- `quickshell/`'s `Colors.qml` also styles the lock screen — see
  `LockScreen.qml` below in the quickshell entry; there's no separate
  `~/.rice/swaylock/` anymore, since swaylock itself was replaced.
- `satty/` — `config.toml` (color palette, save location, save/copy
  actions); same symlink deal as yazi/lazygit/lazydocker (TOML has no include directive).
  Not packaged for apt/dnf — `install.sh`'s `install_satty` grabs the
  prebuilt glibc binary from github.com/Satty-org/Satty's latest release,
  same pattern as yazi/lazygit/lazydocker. Both screenshot binds in
  `~/.config/sway/config` (`Print`, `$mod+Shift+s`) pipe grim/grim+slurp
  into `satty --filename -` for annotation (crop/arrows/blur/numbered
  markers/text, undo/redo) before saving+copying on Enter. Replaced swappy,
  which covered the same job with a smaller toolset
- `firefox/` — `userChrome.css` (the KeyFox one-liner layout, recolored
  black/white/gray). Snap/flatpak Firefox can't read hidden paths under
  `$HOME`, so unlike yazi/lazygit/lazydocker this is *copied*, not
  symlinked: `~/.rice/install.sh`'s `install_firefox_profiles` finds every
  existing profile (snap, flatpak or native — it never installs Firefox)
  and copies it to `chrome/userChrome.css` — re-run it after editing.
  Not wired into the token/template system — it's a plain flat file, not a
  `.tmpl`, so switching rice themes won't recolor it. The "glue" pref
  (`toolkit.legacyUserProfileCustomizations.stylesheets`, plus
  `browser.download.autohideButton`) lives in `~/.rice/desktop/firefox/user.js`,
  copied alongside it, same idea as nvim's `dofile(...)` line living in
  `~/.dots` rather than here.
- `kde/` — `kdeglobals`, a full KDE color scheme (view/window/header/
  button/selection/tooltip groups) plus `Icons/Theme=breeze-dark`. KConfig
  has no include directive, so same symlink deal as yazi:
  `~/.rice/desktop/kde/.config/kdeglobals` points straight at it, stowed to
  `~/.config/kdeglobals`. Themes the KDE flatpaks (Dolphin, Gwenview, Ark),
  which all ship `--filesystem=xdg-config/kdeglobals:ro`. Outside a Plasma
  session they only honor its colors with `QT_QPA_PLATFORMTHEME=kde`
  (otherwise stock Breeze Dark) — `~/.rice/install.sh`'s
  `install_kde_flatpak_theme` sets that as a per-app `flatpak override`.
  Running KDE apps don't recolor live (a `KGlobalSettings.notifyChange`
  D-Bus signal doesn't reach them); they pick up a theme switch on next
  launch.
