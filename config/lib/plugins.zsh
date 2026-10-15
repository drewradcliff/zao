# zoxide gives `z` to jump to directories you've visited: `z zao`.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Suggestions from history in gray as you type; Right arrow or End accepts,
# Option-Right accepts a word. Commands are colored as you type, red when
# they don't exist.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=200
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
ZSH_HIGHLIGHT_STYLES[path]='none'
ZSH_HIGHLIGHT_STYLES[path_prefix]='none'

# Both wrap every key binding that exists when they load, so they load just
# before the first prompt, after the rest of ~/.zshrc has added its own.
_zao_load_plugins() {
  add-zsh-hook -d precmd _zao_load_plugins
  # Skip any that ~/.zshrc already loaded itself.
  local plugin
  local -A loaded=(zsh-autosuggestions _zsh_autosuggest_start zsh-syntax-highlighting _zsh_highlight)
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    (( $+functions[$loaded[$plugin]] )) && continue
    [[ -r $ZAO_BREW/share/$plugin/$plugin.zsh ]] && source $ZAO_BREW/share/$plugin/$plugin.zsh
  done
  (( $+ZSH_AUTOSUGGEST_CLEAR_WIDGETS )) && ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(zao-escape)
}
add-zsh-hook precmd _zao_load_plugins
