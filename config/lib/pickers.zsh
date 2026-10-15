# Pickers built on fzf. On an empty line, a picker does the obvious thing:
# Ctrl-G switches to the branch, Ctrl-O goes to the directory. Partway
# through a command, it types the choice at the cursor instead, so
# `git rebase <Ctrl-G>` works too.
#
# Ctrl-R (history) and Ctrl-T (files) are fzf's own.

(( $+commands[fzf] )) || return 0

: ${FZF_DEFAULT_OPTS='--height=40% --min-height=12 --layout=reverse --info=inline-right --no-scrollbar --pointer=▌ --marker=▌ --prompt="❯ " --color=hl:blue,hl+:blue,pointer:blue,marker:blue,prompt:magenta,info:8,gutter:-1,bg+:-1,fg+:-1:bold,border:8,preview-border:8'}
export FZF_DEFAULT_OPTS
export FZF_ALT_C_COMMAND=  # Ctrl-O replaces Alt-C, which Option doesn't send by default on macOS.
if (( $+commands[fd] )); then
  : ${FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'}
  export FZF_CTRL_T_COMMAND
fi
[[ -r $ZAO_BREW/opt/fzf/shell/key-bindings.zsh ]] && source $ZAO_BREW/opt/fzf/shell/key-bindings.zsh

# Runs `command` on an empty line, or types `arg` at the cursor otherwise.
_zao_pick_done() {
  local command=$1 arg=$2
  if [[ -z $BUFFER ]]; then
    BUFFER="$command $arg"
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
    zle -M 'Not in a git repository'
    return 1
  fi
  local current=$(command git branch --show-current 2>/dev/null)
  local choice=$(
    command git for-each-ref --sort=-committerdate \
      --format=$'%(refname)\t%(refname:lstrip=2)\t%(committerdate:relative)' refs/heads refs/remotes |
      awk -F '\t' -v current="$current" '
        $1 ~ /^refs\/remotes\// { sub(/^[^\/]*\//, "", $2) }
        $2 == "HEAD" || $2 == current || seen[$2]++ { next }
        { printf "%s\t%s\t\033[90m%s\033[0m\n", $1, $2, $3 }' |
      fzf --ansi --delimiter='\t' --with-nth=2.. --nth=1 --tiebreak=index --prompt='branch ❯ ' \
        --preview='git log --color=always --format="%C(yellow)%h%C(reset) %s %C(8)%cr%C(reset)" -30 {1}' \
        --preview-window=right,55%,border-left
  )
  [[ -n $choice ]] || { zle reset-prompt; return }
  choice=${${choice#*$'\t'}%%$'\t'*}
  _zao_pick_done 'git switch' ${(q-)choice}
}

# Directories you've visited, most used first (from zoxide).
_zao_pick_dir() {
  if (( ! $+commands[zoxide] )); then
    zle -M 'Ctrl-O needs zoxide: brew install zoxide'
    return 1
  fi
  local choice=$(
    command zoxide query --list --exclude "$PWD" |
      awk -v home="$HOME" '{ d = $0; if (index(d, home "/") == 1) d = "~" substr(d, length(home) + 1); print $0 "\t" d }' |
      fzf --delimiter='\t' --with-nth=2 --scheme=path --tiebreak=index --prompt='directory ❯ ' \
        --preview='ls -G {1}' --preview-window=right,40%,border-left
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
