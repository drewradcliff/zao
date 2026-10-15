# One history, shared by every open shell. Uses the file you already have.

: ${HISTFILE:=$HOME/.zsh_history}
(( HISTSIZE < 100000 )) && HISTSIZE=100000
(( SAVEHIST < 100000 )) && SAVEHIST=100000

setopt extended_history       # Save when each command ran.
setopt share_history          # Commands from other tabs show up as you go.
setopt hist_ignore_all_dups   # Keep only the latest copy of a command.
setopt hist_ignore_space      # Commands starting with a space aren't saved.
setopt hist_reduce_blanks
setopt hist_verify            # `!!` expands for review instead of running.
