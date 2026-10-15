# Keys that work like a text field on macOS. Terminals send different codes
# for the same key, so each binding lists the ones Ghostty, iTerm2, Terminal,
# and tmux use.

bindkey -e

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zle -N edit-command-line

# Esc on its own dismisses the suggestion, as in Warp. Unbound, it would wait
# for another key and swallow it.
_zao_escape() { : }
zle -N zao-escape _zao_escape

() {
  local widget key
  local -A keys=(
    # Up and Down search history for lines that start with what you've typed.
    up-line-or-beginning-search   '^[[A ^[OA'
    down-line-or-beginning-search '^[[B ^[OB'
    beginning-of-line             '^[[H ^[OH ^[[1~ ^A'
    end-of-line                   '^[[F ^[OF ^[[4~ ^E'
    delete-char                   '^[[3~'
    # Option and Ctrl with the arrows move by word.
    backward-word                 '^[[1;3D ^[[1;5D ^[^[[D ^[b'
    forward-word                  '^[[1;3C ^[[1;5C ^[^[[C ^[f'
    # Option-Backspace and Ctrl-Backspace delete a word, Cmd-Backspace the
    # line before the cursor.
    backward-kill-word            '^[^? ^H ^W'
    kill-word                     '^[[3;3~ ^[[3;5~ ^[d'
    backward-kill-line            '^U'
    reverse-menu-complete         '^[[Z'
    edit-command-line             '^X^E'
    zao-escape                    '^['
  )
  for widget in ${(k)keys}; do
    for key in ${=keys[$widget]}; do
      bindkey $key $widget
    done
  done

  # In the completion menu the arrows move through matches, and Esc cancels.
  local -A menu=(
    up-line-or-history   '^[[A ^[OA'
    down-line-or-history '^[[B ^[OB'
    backward-char        '^[[D ^[OD'
    forward-char         '^[[C ^[OC'
    send-break           '^['
  )
  for widget in ${(k)menu}; do
    for key in ${=menu[$widget]}; do
      bindkey -M menuselect $key $widget
    done
  done
}
