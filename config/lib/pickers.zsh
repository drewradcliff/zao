# Pickers built on fzf. On an empty line, a picker does the obvious thing:
# Ctrl-G switches to the branch, Ctrl-O goes to the directory. Partway
# through a command, it types the choice at the cursor instead, so
# `git rebase <Ctrl-G>` works too.
#
# Ctrl-R (history) and Ctrl-T (files) are fzf's own.
#
# A picker opens on the prompt's ❯ line, so you type where you were already
# typing, and the list opens below it.

(( $+commands[fzf] )) || return 0

: ${FZF_DEFAULT_OPTS='--height=40% --min-height=12 --layout=reverse --info=hidden --no-separator --no-scrollbar --gutter=" " --pointer=▌ --marker=▌ --prompt="  " --color=hl:blue,hl+:blue,pointer:blue,marker:blue,prompt:magenta,info:8,gutter:-1,bg+:-1,fg+:-1:bold,border:8,preview-border:8'}
export FZF_DEFAULT_OPTS
: ${FZF_CTRL_R_OPTS='--with-nth=2.. --ghost="Search history"'} ${FZF_CTRL_T_OPTS='--ghost="Search files"'}
export FZF_CTRL_R_OPTS FZF_CTRL_T_OPTS
export FZF_ALT_C_COMMAND=  # Ctrl-O replaces Alt-C, which Option doesn't send by default on macOS.
if (( $+commands[fd] )); then
  : ${FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'}
  export FZF_CTRL_T_COMMAND
fi
[[ -r $ZAO_BREW/opt/fzf/shell/key-bindings.zsh ]] && source $ZAO_BREW/opt/fzf/shell/key-bindings.zsh

# Sets `reply` to fzf options that open the picker on the ❯ line, and moves
# the cursor to the start of that line, where fzf starts drawing. Fails, so
# the picker opens below the line instead, when the line has text that the
# picker would cover.
_zao_pick_here() {
  reply=()
  [[ -z $BUFFER || ( $1 == query && $BUFFER != *$'\n'* ) ]] || return 1
  reply=(--prompt='❯ ' --color=prompt:$(( _zao_status ? 1 : 5 )))
  print -n -- $'\r'
}

# Ctrl-R puts what you've typed in its search box, so it can always open on
# the ❯ line.
_zao_pick_history() {
  local FZF_CTRL_R_OPTS=$FZF_CTRL_R_OPTS
  _zao_pick_here query && FZF_CTRL_R_OPTS+=" ${(j: :)${(@qq)reply}}"
  zle fzf-history-widget
}

_zao_pick_file() {
  local FZF_CTRL_T_OPTS=$FZF_CTRL_T_OPTS
  _zao_pick_here && FZF_CTRL_T_OPTS+=" ${(j: :)${(@qq)reply}}"
  zle fzf-file-widget
}

# Shows a message under the line until the next key, which then does what
# it normally would.
_zao_pick_say() {
  local key
  zle -M $1
  zle -R
  read -k key
  zle -M ''
  zle -U -- $key
}

# Runs `command` on an empty line, or types `arg` at the cursor otherwise.
_zao_pick_done() {
  local command=$1 arg=$2
  if [[ -z $BUFFER ]]; then
    BUFFER="$command $arg"
    zle reset-prompt
    zle accept-line
  else
    LBUFFER+="$arg "
    zle reset-prompt
  fi
}

# Branches, most recently committed first. Remote branches you don't have
# locally are listed by their short name; `git switch` creates them.
_zao_pick_branch() {
  if ! command git rev-parse --git-dir &>/dev/null; then
    _zao_pick_say 'Not in a git repository'
    return 1
  fi
  local current=$(command git branch --show-current 2>/dev/null)
  local branches=$(
    command git for-each-ref --sort=-committerdate \
      --format=$'%(refname)\t%(refname:lstrip=2)' refs/heads refs/remotes |
      awk -F '\t' -v current="$current" '
        $1 ~ /^refs\/remotes\// { sub(/^[^\/]*\//, "", $2) }
        $2 == "HEAD" || $2 == current || seen[$2]++ { next }
        { print $2 }'
  )
  # fzf shrinks to one line for an empty list, and draws it over the line
  # above. There's nothing to pick anyway.
  if [[ -z $branches ]]; then
    _zao_pick_say 'No other branches'
    return 1
  fi
  local -a reply
  _zao_pick_here
  local choice=$(
    print -r -- $branches |
      fzf --height=~11 --tiebreak=index --ghost='Search branches' $reply
  )
  [[ -n $choice ]] || { zle reset-prompt; return }
  _zao_pick_done 'git switch' ${(q-)choice}
}

# Directories you've visited, most used first (from zoxide).
_zao_pick_dir() {
  if (( ! $+commands[zoxide] )); then
    _zao_pick_say 'Ctrl-O needs zoxide: brew install zoxide'
    return 1
  fi
  local dirs=$(
    command zoxide query --list --exclude "$PWD" |
      awk -v home="$HOME" '{ d = $0; if (index(d, home "/") == 1) d = "~" substr(d, length(home) + 1); print $0 "\t" d }'
  )
  if [[ -z $dirs ]]; then
    _zao_pick_say 'No directories yet. Ctrl-O lists the ones you cd into.'
    return 1
  fi
  local -a reply
  _zao_pick_here
  local choice=$(
    print -r -- $dirs |
      fzf --height=~11 --delimiter='\t' --with-nth=2 --scheme=path --tiebreak=index \
        --ghost='Search directories' $reply
  )
  [[ -n $choice ]] || { zle reset-prompt; return }
  choice=${choice%%$'\t'*}
  if [[ $choice == $HOME/* ]]; then
    choice="~/${(q-)choice#$HOME/}"
  else
    choice=${(q-)choice}
  fi
  _zao_pick_done cd $choice
}

zle -N zao-pick-branch _zao_pick_branch
zle -N zao-pick-dir _zao_pick_dir
bindkey '^G' zao-pick-branch
bindkey '^O' zao-pick-dir
if (( $+widgets[fzf-history-widget] )); then
  zle -N zao-pick-history _zao_pick_history
  bindkey '^R' zao-pick-history
fi
if (( $+widgets[fzf-file-widget] )); then
  zle -N zao-pick-file _zao_pick_file
  bindkey '^T' zao-pick-file
fi
