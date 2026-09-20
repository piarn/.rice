# .rice

Rice repo, built around one idea: **the palette lives in one file, and
everything else is generated from it.**

## Changing/switching the theme

```
~/.rice/bin/apply-theme            # re-render the current theme (after editing it)
~/.rice/bin/apply-theme <name>     # switch to ~/.rice/themes/<name>.toml and render it
~/.rice/bin/apply-theme <name> --dry-run   # show what would change, write nothing
```

Edit a color in `~/.rice/themes/<name>.toml`, run `apply-theme`, and every
app's theme file under `~/.rice/<app>/...` gets re-rendered from
`~/.rice/templates/<app>/*.tmpl`. `~/.rice/themes/current` remembers which
theme is active.

To add a new theme: copy `themes/toxic.toml` to `themes/<name>.toml`, change
the `[colors]` values, then `apply-theme <name>`. Templates reference colors
by role (`neon`, `dim`, `red`, ...), not by value, so any theme that defines
the same roles drops in without touching a single app config.

## Current theme: Toxic

Black & toxic-waste-green.

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

Full source of truth (including the bright-ANSI ramp) is
`~/.rice/themes/toxic.toml`.

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
  `~/.dots/foot/.config/foot/foot.ini`
- `sway/` — window border colors and gaps, included via
  `include ~/.rice/sway/theme.conf` (the status bar and launcher are
  quickshell now, not swaybar/wofi — see `quickshell/` below). `gaps
  inner/outer` in a config file only sets the default for workspaces
  created *after* a reload — already-open ones keep their old gap value
  otherwise (a sway quirk) — so `theme.conf` also carries an `exec_always`
  that replays the gap values as live `gaps ... all set N` IPC commands on
  every reload. `sway/outputs.conf` is a separate generated file (not
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
- `quickshell/` — bar + app launcher, replacing waybar/swaybar and wofi.
  `Colors.qml` is a `pragma Singleton` QML object rendered from
  `templates/quickshell/Colors.qml.tmpl`, paired with a static (untemplated)
  `qmldir` that declares it — same "just a plain file, not rendered"
  exception as `yazi/theme.toml` below, except here it's the *loader*, not
  the theme file itself, that has no include-directive equivalent to lean
  on. `~/.dots/quickshell`'s QML (`shell.qml`, `Bar.qml`, `Launcher.qml`)
  pulls it in via `import quickshell`, an unquoted module import resolved
  through `QML2_IMPORT_PATH=$HOME/.rice` (set inline on the `exec_always`
  in `~/.config/sway/config`) — a quoted relative import
  (`import "../../.rice/quickshell"`) does *not* work here, because
  quickshell loads each config into a virtual `qs:/` resource tree where
  `..` never escapes `~/.config/quickshell`. The bar's few icon glyphs
  (bluetooth on/off) need `~/.local/share/fonts/NerdFontSymbols`
  (`install.sh`'s `install_nerd_font_symbols`) — plain "monospace" has no
  bluetooth glyph, patched or otherwise, confirmed by screenshotting actual
  candidate codepoints rather than trusting a font's cmap table (several
  looked present in Noto Sans Mono's cmap but rendered as nothing).
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
- `swaylock/` — `config` (ring/text/indicator colors); same symlink deal as
  yazi/lazygit/lazydocker. Invoked via
  `~/.dots/scripts/.local/bin/lockscreen` (grim screenshot + ImageMagick
  blur, then `swaylock -i`), bound to `$mod+Escape` in `~/.config/sway/config`
- `satty/` — `config.toml` (color palette, save location, save/copy
  actions); same symlink deal as swaylock (TOML has no include directive).
  Not packaged for apt/dnf — `install.sh`'s `install_satty` grabs the
  prebuilt glibc binary from github.com/Satty-org/Satty's latest release,
  same pattern as yazi/lazygit/lazydocker. Both screenshot binds in
  `~/.config/sway/config` (`Print`, `$mod+Shift+s`) pipe grim/grim+slurp
  into `satty --filename -` for annotation (crop/arrows/blur/numbered
  markers/text, undo/redo) before saving+copying on Enter. Replaced swappy,
  which covered the same job with a smaller toolset
- `firefox/` — `userChrome.css` (the KeyFox one-liner layout, recolored
  black/white/gray); CSS has no include directive either, so
  `~/.config/mozilla/firefox/<profile>/chrome/userChrome.css` is a relative
  symlink straight to it, same deal as yazi/lazygit/lazydocker/swaylock.
  Not wired into the token/template system — it's a plain flat file, not a
  `.tmpl`, so switching rice themes won't recolor it. The "glue" pref
  (`toolkit.legacyUserProfileCustomizations.stylesheets`, plus
  `browser.download.autohideButton`) lives in the profile's own `user.js`,
  same idea as nvim's `dofile(...)` line living in `~/.dots` rather than
  here. Note the profile directory has a random suffix per machine/install,
  so this symlink needs re-pointing (or the profile's chrome dir needs
  recreating) on a fresh Firefox profile.
