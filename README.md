# .rice — Toxic

Black & toxic-waste-green theme. Each app folder holds a theme file that gets
included/imported from the app's real config, so the palette lives in one
place.

## Palette

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

## Apps

- `ghostty/` — terminal, included via `config-file = ?~/.rice/ghostty/theme.conf`
- `sway/` — window border colors, included via `include ~/.rice/sway/theme.conf`
  (bar colors are inlined directly in `~/.config/sway/config` — sway's
  `include` can't nest inside the `bar { colors { } }` block, so they're kept
  in sync by hand with the palette above)
- `wofi/` — launcher, imported via `@import` from `~/.config/wofi/style.css`
- `tmux/` — status bar / panes / messages, sourced via `source-file ~/.rice/tmux/theme.conf`
  from `~/.dots/tmux/.config/tmux/tmux.conf`
- `nvim/` — editor chrome only (statusline, splits, popups, gutter, signs —
  never Comment/String/Function/`@`-treesitter groups), loaded via
  `dofile(vim.fn.expand("~/.rice/nvim/theme.lua"))` from
  `~/.dots/nvim/.config/nvim/lua/config/theme.lua`
