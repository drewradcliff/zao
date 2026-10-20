# Two-line prompt with a blank line between commands, so each command and
# its output reads as one block:
#
#   v20.19.5 ~/repos/zao main* ⇡1 PR #325 4s
#   ❯
#
# The Node version shows in Node projects, and is read from the path of the
# `node` binary where a version manager keeps one per directory, so it costs
# nothing. The branch is read straight from .git, so it shows instantly.
# Whether the tree is dirty, and how far it is from upstream, comes from
# `git status` in the background and fills in when it's ready. So does the
# branch's open pull request, from `gh`.

zmodload zsh/datetime zsh/zselect

typeset -g _zao_gap=0 _zao_cmd_start= _zao_cmd_time=
typeset -gi _zao_status=0
typeset -g _zao_git_dir= _zao_git_branch= _zao_git_head= _zao_git_action= _zao_git_status= _zao_git_status_for=
typeset -gi _zao_git_fd=0
typeset -g _zao_node=
typeset -gA _zao_node_versions
typeset -g _zao_pr= _zao_pr_for= _zao_pr_started=
typeset -gi _zao_pr_fd=0 _zao_pr_timer_fd=0 _zao_pr_ran_gh=0

_zao_preexec() {
  _zao_cmd_start=$EPOCHREALTIME
  # Don't push the first prompt after `clear` down a line.
  [[ $2 == (clear|reset)(| *) ]] && _zao_gap=0
  # gh and gt (Graphite) open, close and merge pull requests without
  # touching .git.
  [[ ${${(z)3}[1]} == (gh|gt) ]] && _zao_pr_ran_gh=1
}

_zao_precmd() {
  _zao_status=$?  # For the pickers, which draw their own ❯.
  (( _zao_gap )) && print
  _zao_gap=1

  _zao_cmd_time=
  if [[ -n $_zao_cmd_start ]]; then
    local -i secs=$(( EPOCHREALTIME - _zao_cmd_start ))
    _zao_cmd_start=
    if (( secs >= 3 )); then
      (( secs >= 3600 )) && _zao_cmd_time+="$(( secs / 3600 ))h "
      (( secs >= 60 )) && _zao_cmd_time+="$(( secs % 3600 / 60 ))m "
      _zao_cmd_time+="$(( secs % 60 ))s"
    fi
  fi

  _zao_git_read_head
  _zao_node_read
  _zao_git_status_start
  _zao_pr_update
  _zao_prompt_render
}

# Finds the repository and its branch without running git.
_zao_git_read_head() {
  _zao_git_dir= _zao_git_branch= _zao_git_head= _zao_git_action=
  local dir=$PWD gitdir line
  while [[ ! -e $dir/.git ]]; do
    [[ $dir == / ]] && return
    dir=${dir:h}
  done
  gitdir=$dir/.git
  # Worktrees and submodules have a .git file pointing at the real one.
  if [[ -f $gitdir ]]; then
    IFS= read -r line < $gitdir || return
    gitdir=${line#gitdir: }
    [[ $gitdir == /* ]] || gitdir=$dir/$gitdir
  fi
  IFS= read -r line < $gitdir/HEAD 2>/dev/null || return
  _zao_git_dir=$dir
  if [[ $line == 'ref: refs/heads/'* ]]; then
    _zao_git_branch=${line#ref: refs/heads/}
    _zao_git_head=$_zao_git_branch
  else
    _zao_git_head=${line[1,7]}
  fi
  if [[ -d $gitdir/rebase-merge || -d $gitdir/rebase-apply ]]; then
    _zao_git_action=rebasing
  elif [[ -f $gitdir/MERGE_HEAD ]]; then
    _zao_git_action=merging
  elif [[ -f $gitdir/CHERRY_PICK_HEAD ]]; then
    _zao_git_action=cherry-picking
  elif [[ -f $gitdir/REVERT_HEAD ]]; then
    _zao_git_action=reverting
  elif [[ -f $gitdir/BISECT_LOG ]]; then
    _zao_git_action=bisecting
  fi
}

# Finds the Node version, if there's a package.json here or above, up to the
# repository's root.
_zao_node_read() {
  _zao_node=
  local dir=$PWD
  until [[ -e $dir/package.json ]]; do
    [[ $dir == (${_zao_git_dir:-$PWD}|/) ]] && return
    dir=${dir:h}
  done
  (( $+commands[node] )) || return
  local bin=${commands[node]:A}
  local -a match mbegin mend
  # fnm, nvm, mise and Homebrew keep each version in its own directory.
  if [[ $bin =~ '/v?([0-9]+\.[0-9]+\.[0-9]+)[^/]*/' ]]; then
    _zao_node=v$match[1]
    return
  fi
  # Otherwise ask node, once per binary. Shims, like Volta's, pick a version
  # per project, so ask them once per project.
  local key=$bin
  [[ $bin == *shim* ]] && key+=:$dir
  (( $+_zao_node_versions[$key] )) ||
    _zao_node_versions[$key]=$(command node --version 2>/dev/null)
  _zao_node=$_zao_node_versions[$key]
}

# Prints "<dirty> <ahead> <behind>" for the repository in $PWD.
_zao_git_status_job() {
  local line dirty=0 ahead=0 behind=0
  GIT_OPTIONAL_LOCKS=0 command git status --porcelain=v2 --branch --ignore-submodules=dirty 2>/dev/null |
    while IFS= read -r line; do
      case $line in
        ('# branch.ab '*)
          line=${line#\# branch.ab +}
          ahead=${line%% *} behind=${line##*-} ;;
        ('#'*) ;;
        (*) dirty=1; break ;;
      esac
    done
  print -r -- "$dirty $ahead $behind"
}

_zao_git_status_start() {
  _zao_git_status_stop
  if [[ -z $_zao_git_dir ]]; then
    _zao_git_status= _zao_git_status_for=
    return
  fi
  # Keep showing the last result for this repository until the new one is in,
  # so the prompt doesn't flicker.
  [[ $_zao_git_status_for == $_zao_git_dir ]] || _zao_git_status=
  exec {_zao_git_fd}< <(_zao_git_status_job)
  # Small repositories answer within a few milliseconds; wait up to 20ms so the
  # prompt draws once, complete.
  if zselect -t 2 -r $_zao_git_fd 2>/dev/null; then
    _zao_git_status_read $_zao_git_fd
  else
    zle -F $_zao_git_fd _zao_git_status_ready
  fi
}

_zao_git_status_stop() {
  (( _zao_git_fd )) || return
  zle -F $_zao_git_fd 2>/dev/null
  exec {_zao_git_fd}<&-
  _zao_git_fd=0
}

_zao_git_status_read() {
  local out
  IFS= read -r -u $1 out
  _zao_git_status_stop
  _zao_git_status=$out
  _zao_git_status_for=$_zao_git_dir
}

# Called by zle when the background `git status` finishes.
_zao_git_status_ready() {
  if [[ -n $2 ]]; then
    _zao_git_status_stop
    return
  fi
  _zao_git_status_read $1
  _zao_prompt_render
  zle reset-prompt
}

# Keeps the branch's open pull request up to date: look
# it up with `gh` in the background when the branch changes, after a `gh` or
# `gt` command, and every minute.
_zao_pr_update() {
  local key=
  [[ -n $_zao_git_branch ]] && (( $+commands[gh] )) && key=$_zao_git_dir:$_zao_git_branch
  if [[ $key != $_zao_pr_for ]]; then
    _zao_pr_stop
    _zao_pr= _zao_pr_for=$key
    _zao_pr_fetch
  elif (( _zao_pr_ran_gh )); then
    _zao_pr_fetch
  fi
  _zao_pr_ran_gh=0
  _zao_pr_timer_start
}

# Prints "<number> <url>" for the branch's open pull request, or "none" if
# there isn't one or `gh` can't say here (no GitHub remote, not logged in).
# Prints nothing if the lookup failed, say offline.
_zao_pr_job() {
  local out
  local -a pr
  if out=$(GH_PROMPT_DISABLED=1 GH_NO_UPDATE_NOTIFIER=1 command gh pr view \
      --json number,url,state --jq 'select(.state == "OPEN") | "\(.number) \(.url)"' 2>&1 </dev/null); then
    pr=(${(M)${(f)out}:#<-> *})
    print -r -- ${pr[1]:-none}
  elif [[ ${out:l} == *('no pull requests found'|'no open pull requests found'|'known github host'|'no github remotes'|'not a github repository'|'could not determine base repo'|'not logged in'|'authentication required'|'gh auth login')* ]]; then
    print none
  fi
}

_zao_pr_fetch() {
  [[ -n $_zao_pr_for ]] || return
  # One at a time, but give up on one that's taken more than five seconds.
  if (( _zao_pr_fd )); then
    (( EPOCHREALTIME - _zao_pr_started < 5 )) && return
    _zao_pr_stop
  fi
  _zao_pr_started=$EPOCHREALTIME
  exec {_zao_pr_fd}< <(_zao_pr_job)
  zle -F $_zao_pr_fd _zao_pr_ready
}

_zao_pr_stop() {
  (( _zao_pr_fd )) || return
  zle -F $_zao_pr_fd 2>/dev/null
  exec {_zao_pr_fd}<&-
  _zao_pr_fd=0
}

# Called by zle when `gh` finishes. A failed lookup keeps what's showing, so
# the prompt doesn't flicker.
_zao_pr_ready() {
  local out=
  [[ -n $2 ]] || IFS= read -r -u $1 out
  _zao_pr_stop
  [[ -n $out ]] || return
  [[ $out == none ]] && out=
  [[ $out != $_zao_pr ]] || return
  _zao_pr=$out
  _zao_prompt_render
  zle reset-prompt
}

# A minute's timer, so a pull request opened or merged elsewhere shows up
# while you sit at the prompt. Once it's out of a repository, it stops.
_zao_pr_timer_start() {
  [[ -n $_zao_pr_for ]] && (( ! _zao_pr_timer_fd )) || return
  exec {_zao_pr_timer_fd}< <(command sleep 60)
  zle -F $_zao_pr_timer_fd _zao_pr_timer_ready
}

_zao_pr_timer_ready() {
  zle -F $_zao_pr_timer_fd
  exec {_zao_pr_timer_fd}<&-
  _zao_pr_timer_fd=0
  _zao_pr_fetch
  _zao_pr_timer_start
}

_zao_prompt_render() {
  local p=
  [[ -n $SSH_CONNECTION ]] && p+='%F{8}%n@%m%f '
  [[ -n $_zao_node ]] && p+="%F{green}${_zao_node//\%/%%}%f "
  p+='%F{blue}%~%f'

  if [[ -n $_zao_git_head ]]; then
    # Long branch names keep their end, which is usually what tells them apart.
    local head=$_zao_git_head
    (( $#head > 40 )) && head=…${head[-39,-1]}
    p+=" %F{8}${head//\%/%%}%f"
    local -a git=(${=_zao_git_status})
    (( git[1] )) && p+='%F{yellow}*%f'
    [[ -n $_zao_git_action ]] && p+=" %F{yellow}$_zao_git_action%f"
    (( git[3] )) && p+=" %F{cyan}⇣$git[3]%f"
    (( git[2] )) && p+=" %F{cyan}⇡$git[2]%f"
  fi

  # Links to the pull request, in terminals that support links.
  if [[ -n $_zao_pr ]]; then
    local url=${${_zao_pr#* }//\%/%%}
    p+=" %{"$'\e]8;;'$url$'\e\\'"%}%F{magenta}PR #${_zao_pr%% *}%f%{"$'\e]8;;\e\\'"%}"
  fi

  if [[ -n $VIRTUAL_ENV ]]; then
    local venv=${VIRTUAL_ENV:t}
    [[ $venv == (.|)venv ]] && venv=${VIRTUAL_ENV:h:t}
    p+=" %F{8}(${venv//\%/%%})%f"
  fi

  [[ -n $_zao_cmd_time ]] && p+=" %F{yellow}$_zao_cmd_time%f"

  PROMPT="$p"$'\n''%(?.%F{magenta}.%F{red})❯%f '
}

PS2='%F{8}·%f '
RPROMPT=

autoload -Uz add-zsh-hook
add-zsh-hook preexec _zao_preexec
add-zsh-hook precmd _zao_precmd
