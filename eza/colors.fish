# Toxic — eza colors.
# Sourced from ~/.dots/fish/.config/fish/conf.d/00-rice.fish.

set -gx EZA_CONFIG_DIR ~/.rice/eza

# eza applies LS_COLORS then EZA_COLORS *after* theme.yml, so these reclaim
# the ten classic file-kind codes from whatever LS_COLORS this system
# already exports (dircolors) — matches ~/.rice/eza/theme.yml's filekinds.
set -gx EZA_COLORS "di=1;38;2;57;255;20:ln=3;38;2;0;230;184:ex=1;38;2;173;255;47:pi=38;2;204;255;0:so=38;2;255;63;208:bd=1;38;2;0;191;255:cd=1;38;2;0;191;255:or=1;38;2;255;59;48"
