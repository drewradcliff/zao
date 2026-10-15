#!/bin/zsh
# Starts zao in a real interactive shell, on a pseudo-terminal, types into it,
# and checks what it draws and runs. From the repository root:
#
#   zsh .github/test.zsh

zmodload zsh/zpty
setopt extended_glob

root=${0:A:h:h}
tmp=$(mktemp -d)
trap 'zpty -d zao 2>/dev/null; rm -rf $tmp' EXIT
mkdir -p $tmp/zdotdir $tmp/repo/alpha-dir $tmp/repo/beta-dir
print -r -- "eval \"\$($root/bin/zao init)\"" > $tmp/zdotdir/.zshrc

failures=0
fail() { print -u2 "FAIL: $1"; (( failures++ )) }

# What the shell has drawn since the last check, without escape codes. The
# shell blocks once the terminal's buffer fills, so keep reading it.
typeset -g screen=
drain() {
  local chunk
  while zpty -rt zao chunk 2>/dev/null; do screen+=$chunk; done
  screen=${${screen//$'\e'\[[0-9;?]#[a-zA-Z]/}//$'\r'/}
}

# Waits up to two seconds for text to appear on screen.
expect() {
  local i
  for i in {1..40}; do
    drain
    [[ $screen == *$1* ]] && return 0
    sleep 0.05
  done
  return 1
}

# Types keys without pressing Enter, then gives the shell a moment.
keys() { zpty -wn zao "$1"; sleep ${2:-0.3}; drain }
# Types a line and presses Enter.
run() { screen=; zpty -w zao "$1" }
# Waits up to two seconds for the shell to write a file, then prints it.
output() {
  local i
  for i in {1..40}; do
    [[ -s $tmp/repo/$1 ]] && break
    sleep 0.05
    drain
  done
  [[ -f $tmp/repo/$1 ]] && print -r -- "$(<$tmp/repo/$1)"
}

export ZDOTDIR=$tmp/zdotdir HISTFILE=$tmp/history TERM=xterm-256color
export XDG_CACHE_HOME=$tmp/cache _ZO_DATA_DIR=$tmp/zoxide
cd $tmp
zpty zao zsh -i

expect '❯' || fail "no prompt after startup: ${(q+)screen}"
[[ $screen == *(error|not found|parse|bad )* ]] && fail "errors at startup: ${(q+)screen}"

run 'print -r -- ok:$ZAO_ROOT'
expect "ok:$root/config" || fail "zao didn't load from the checkout: ${(q+)screen}"

run 'print -r -- loaded:${+widgets[autosuggest-accept]}${+widgets[zao-pick-branch]}${+functions[_zsh_highlight]}'
expect 'loaded:111' || fail "plugins and pickers didn't load: ${(q+)screen}"

# Prompt
git -C $tmp/repo init -q -b trunk
git -C $tmp/repo -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C $tmp/repo branch feature-x
run "cd ${(q)tmp}/repo"
expect $'repo trunk\n' || fail "prompt doesn't show the branch: ${(q+)screen}"

run 'touch new-file'
expect 'trunk*' || fail "prompt doesn't show a dirty repo: ${(q+)screen}"

# Completion menu: the first Tab opens it, the arrows move, Enter picks
# without running the line.
keys 'ls -d '; keys $'\t' 0.6; keys $'\e[C'; keys $'\r'; run ' > menu-pick'
[[ $(output menu-pick) == beta-dir ]] || fail "Tab, Right, Enter didn't pick the second match: $(output menu-pick)"

# Esc closes the menu and restores the line; Ctrl-U then clears it.
keys 'ls -d '; keys $'\t' 0.6; keys $'\e' 0.6; keys $'\C-u'; run 'print -r -- cleared > menu-esc'
[[ $(output menu-esc) == cleared ]] || fail "Esc in the menu didn't restore the line"

# Esc on a plain line doesn't swallow the next key.
keys 'junk'; keys $'\e' 0.6; keys $'\C-u'; run 'print -r -- cleared > plain-esc'
[[ $(output plain-esc) == cleared ]] || fail "Esc on a plain line swallowed the next key"

# Suggestions from history: End accepts one, Esc dismisses it.
run 'print -r -- suggested-command > /dev/null'
expect '❯'
keys 'print -r -- sugg' 0.6; keys $'\e[F'; run ' > suggest-end'
[[ $(output suggest-end) == suggested-command ]] || fail "End didn't accept the suggestion: $(output suggest-end)"
keys 'print -r -- sugg' 0.6; keys $'\e' 0.6; keys $'\e[F'; run 'X > suggest-esc'
[[ $(output suggest-esc) == suggX ]] || fail "Esc didn't dismiss the suggestion: $(output suggest-esc)"

# Ctrl-G on an empty line switches to the chosen branch.
keys $'\C-g' 1; keys 'feat' 0.5; keys $'\r'
expect 'feature-x*' || fail "Ctrl-G didn't switch branches: ${(q+)screen}"

run 'exit'
(( failures )) && exit 1
print 'All checks passed'
