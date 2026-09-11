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
- `sway/` — window border colors, included via `include ~/.rice/sway/theme.conf`
  (the status bar itself is waybar now, not swaybar — see `waybar/` below)
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
