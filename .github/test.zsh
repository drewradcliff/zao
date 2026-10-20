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

# Waits up to five seconds for text to appear on screen.
expect() {
  local i
  for i in {1..100}; do
    drain
    [[ $screen == *$1* ]] && return 0
    sleep 0.05
  done
  return 1
}

# Waits until the shell has drawn nothing new for 0.3 seconds, up to five.
settle() {
  local i quiet=0 before
  for i in {1..100}; do
    before=$screen
    sleep 0.05
    drain
    [[ $screen == $before ]] && (( ++quiet >= 6 )) && return 0
    [[ $screen == $before ]] || quiet=0
  done
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

# The Node version shows anywhere in a Node project, and nowhere else.
if (( $+commands[node] )); then
  node_version=$(node --version)
  mkdir -p $tmp/web/src && print '{}' > $tmp/web/package.json
  git -C $tmp/web init -q
  run "cd ${(q)tmp}/web/src"
  expect "$node_version /" || fail "prompt doesn't show the Node version: ${(q+)screen}"
  run "cd ${(q)tmp}"
  expect '❯' && settle
  [[ $screen == *$node_version* ]] && fail "prompt shows the Node version outside a Node project: ${(q+)screen}"
  run "cd ${(q)tmp}/repo"
  expect 'trunk*' || fail "didn't return to the repository: ${(q+)screen}"
fi

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
# Suggestions are fetched in the background, so let the shell finish drawing
# before each check.
run 'print -r -- suggested-command > /dev/null'
settle; screen=
keys 'print -r -- sugg'
expect 'ested-command' || fail "no suggestion appeared: ${(q+)screen}"
settle
keys $'\e[F'; run ' > suggest-end'
[[ $(output suggest-end) == suggested-command ]] || fail "End didn't accept the suggestion: $(output suggest-end)"
settle; screen=
keys 'print -r -- sugg'
expect 'ested-command' || fail "no suggestion appeared: ${(q+)screen}"
settle
keys $'\e' 0.6; keys $'\e[F'; run 'X > suggest-esc'
[[ $(output suggest-esc) == suggX ]] || fail "Esc didn't dismiss the suggestion: $(output suggest-esc)"

# Ctrl-R puts the chosen command on the line. The list hides history numbers,
# but fzf's widget still needs them to find the command.
run 'print -r -- from-history >> history-pick'
output history-pick > /dev/null; settle
keys $'\C-r' 1; keys 'from-history' 0.5; keys $'\r' 1; keys $'\r'
expect 'from-history' && settle
[[ $(output history-pick) == $'from-history\nfrom-history' ]] || fail "Ctrl-R didn't put the command on the line: $(output history-pick)"

# Ctrl-G on an empty line switches to the chosen branch.
keys $'\C-g' 1; keys 'feat' 0.5; keys $'\r'
expect 'feature-x*' || fail "Ctrl-G didn't switch branches: ${(q+)screen}"

# With no other branches, Ctrl-G says so instead of opening an empty list.
git init -q $tmp/solo
git -C $tmp/solo -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
run "cd ${(q)tmp}/solo"; settle
keys $'\C-g' 1
expect 'No other branches' || fail "Ctrl-G didn't say there are no other branches: ${(q+)screen}"

run 'exit'
(( failures )) && exit 1
print 'All checks passed'
