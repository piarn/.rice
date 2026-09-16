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

- `ghostty/` — terminal, included via `config-file = ?~/.rice/ghostty/theme.conf`
- `sway/` — window border colors and gaps, included via
  `include ~/.rice/sway/theme.conf` (the status bar itself is waybar now,
  not swaybar — see `waybar/` below). `gaps inner/outer` in a config file
  only sets the default for workspaces created *after* a reload —
  already-open ones keep their old gap value otherwise (a sway quirk) —
  so `theme.conf` also carries an `exec_always` that replays the gap
  values as live `gaps ... all set N` IPC commands on every reload.
  `sway/outputs.conf` is a separate generated file (not theme-related,
  see `layouts/` below), included right after it from
  `~/.config/sway/config`.
- `layouts/` — screen (output) profiles, one per physical setup, e.g.
  `home-office.conf` (docked: ultrawide + a flipped second monitor +
  laptop panel) and `laptop.conf` (undocked: laptop panel only, externals
  disabled). Each profile is plain sway `output` config plus a
  `# requires: OUT-1,OUT-2,...` comment naming the outputs it needs.
  Switch with `~/.rice/bin/apply-layout <name>`, or let it auto-detect
  with `apply-layout --auto` (picks whichever profile's `requires:` set
  is fully connected, preferring the most specific match).
  `~/.rice/bin/layout-watch` is a small daemon, started via
  `exec_always` from `~/.config/sway/config`, that subscribes to sway's
  output-change events and calls `apply-layout --auto` on dock/undock; it
  takes an exclusive lock on a runtime file so re-running it on every
  config reload doesn't pile up processes. `layouts/current` remembers
  which profile is active, same pattern as `themes/current`.
- `waybar/` — `style.css` imported via `@import` from `~/.config/waybar/style.css`
  (functional config lives in `~/.dots/waybar`; swapped in for swaybar since
  swaybar can't center a module or lay out network/battery)
- `yazi/` — `theme.toml` (TOML has no include directive, so this file *is*
  the config): `~/.dots/yazi/.config/yazi/theme.toml` is a relative symlink
  straight to it, stowed to `~/.config/yazi/theme.toml`. Themes UI chrome and
  the broad filetype mime groups; leaves the per-extension icon/brand-color
  tables alone, same call as nvim's syntax highlighting
- `wofi/` — launcher, imported via `@import` from `~/.config/wofi/style.css`
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
