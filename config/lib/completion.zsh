# Tab opens a menu of completions, with descriptions, that you move through
# with the arrow keys. Enter picks one. Esc puts the line back.

zmodload zsh/complist

# Completions installed by Homebrew packages
[[ -d $ZAO_BREW/share/zsh/site-functions ]] && fpath=($ZAO_BREW/share/zsh/site-functions $fpath)

# Rebuild the completion index once a day. Otherwise load the saved one, which
# is much faster.
() {
  setopt local_options extended_glob
  local dump=$ZAO_CACHE/zcompdump
  autoload -Uz compinit
  if [[ -f $dump && -z $dump(#qN.mh+24) ]]; then
    compinit -C -d $dump
  else
    compinit -i -d $dump
    touch $dump
  fi
  { [[ $dump.zwc -nt $dump ]] || zcompile $dump } &!
}

setopt complete_in_word always_to_end

zstyle ':completion:*' menu yes select
# Case-insensitive, and `fb` matches `foo-bar` and `foo_bar`.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-dirs-first true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} 'ma=37;44'
zstyle ':completion:*:descriptions' format '%F{8}%d%f'
zstyle ':completion:*:messages' format '%F{8}%d%f'
zstyle ':completion:*:warnings' format '%F{8}No matches%f'
zstyle ':completion:*:default' list-prompt '%F{8}%p%f'
zstyle ':completion:*:default' select-prompt '%F{8}%p%f'
zstyle ':completion:*' use-cache true
zstyle ':completion:*' cache-path $ZAO_CACHE/completion
# Most recently used first, rather than alphabetical.
zstyle ':completion:*:git-(checkout|switch):*' sort false
zstyle ':completion:*:*:kill:*:processes' command 'ps -u $USERNAME -o pid,%cpu,command'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=34'
