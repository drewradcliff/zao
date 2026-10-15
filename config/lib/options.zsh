# Shell behavior. Closer to what people expect from bash and macOS than zsh's
# own defaults, without changing how scripts run.

setopt auto_cd               # Type a directory's name to go there.
setopt auto_pushd pushd_ignore_dups pushd_silent  # `cd -<Tab>` lists recent directories.
setopt interactive_comments  # Pasted commands can have # comments.
setopt no_nomatch            # Pass unmatched globs through, like bash: `curl example.com/?q=1`.
setopt no_beep
setopt no_flow_control       # Frees Ctrl-S and Ctrl-Q.

# Option-Backspace and Option-Arrow stop at punctuation, as in macOS text fields.
WORDCHARS='_'

export CLICOLOR=1
: ${LSCOLORS:=exgxfxdxcxegedabagacad}
: ${LS_COLORS:='di=34:ln=36:so=35:pi=33:ex=32:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'}
export LSCOLORS LS_COLORS

# Commands like `git commit` and Ctrl-X Ctrl-E open the first editor found.
if [[ -z $EDITOR ]]; then
  for EDITOR in wok nvim vim vi; do
    (( $+commands[$EDITOR] )) && break
  done
  export EDITOR
fi

# Python virtualenvs show in zao's prompt instead of changing it.
export VIRTUAL_ENV_DISABLE_PROMPT=1

alias ll='ls -lh'
alias la='ls -lAh'
