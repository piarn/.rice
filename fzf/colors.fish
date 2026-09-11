# Toxic — fzf colors.
# Sourced from ~/.dots/fish/.config/fish/conf.d/00-rice.fish, *before*
# fzf.fish's _fzf_wrapper.fish sets its own defaults (it only does that when
# FZF_DEFAULT_OPTS is completely unset) — so this repeats fzf.fish's base
# options and adds --color on top, rather than just appending a color string.

set -gx FZF_DEFAULT_OPTS '--cycle --layout=reverse --border --height=90% --preview-window=wrap --marker="*" --color=fg:#D9FFD9,bg:#000000,hl:#39FF14,fg+:#000000,bg+:#1F4D0F,hl+:#ADFF2F,info:#ADFF2F,border:#1F4D0F,prompt:#39FF14,pointer:#39FF14,marker:#ADFF2F,spinner:#39FF14,header:#4D4D4D,gutter:#000000'
