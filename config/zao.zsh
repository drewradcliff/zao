# zao: zsh without the config. `eval "$(zao init)"` in ~/.zshrc sources this.
# Your own settings go after that line in ~/.zshrc, so they override zao's.

[[ -o interactive ]] || return 0
# Re-sourcing ~/.zshrc would stack hooks and widgets; start a new shell instead.
(( ${+ZAO_ROOT} )) && return 0

typeset -g ZAO_ROOT=${${(%):-%x}:A:h}
typeset -g ZAO_CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/zao
[[ -d $ZAO_CACHE ]] || mkdir -p $ZAO_CACHE

# Homebrew's prefix, found without running `brew --prefix`, which is slow.
typeset -g ZAO_BREW=${HOMEBREW_PREFIX:-/opt/homebrew}
[[ -d $ZAO_BREW ]] || ZAO_BREW=/usr/local

source $ZAO_ROOT/lib/options.zsh
source $ZAO_ROOT/lib/history.zsh
source $ZAO_ROOT/lib/completion.zsh
source $ZAO_ROOT/lib/keys.zsh
source $ZAO_ROOT/lib/prompt.zsh
source $ZAO_ROOT/lib/pickers.zsh
source $ZAO_ROOT/lib/plugins.zsh
