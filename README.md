# zao

zsh without the config.

Install it, add one line to `~/.zshrc`, and use it. 

```sh
brew install drewradcliff/tap/zao
echo 'eval "$(zao init)"' >> ~/.zshrc
```

## What's different

- **Upgrades like an app.** `brew upgrade zao`
- **Still zsh.**
- **Modern terminal feeling.**
- **Fast.**

| Key | Action |
| --- | --- |
| `Tab` | Completion menu, `Enter` picks, `Esc` cancels |
| `→` | Accept suggestion |
| `↑` `↓` | History |
| `Ctrl-R` | Search history |
| `Ctrl-T` | Find a file and insert its path |
| `Ctrl-G` | Switch branch |
| `Ctrl-O` | Go to a recent directory |

See [all keys](docs/keys.md)

## Getting around

`z` jumps to any directory you've been to, by part of its name:

```sh
z wok        # ~/repos/wok
```

`Ctrl-O` lists those directories, most used first. `Ctrl-G` lists branches, most recent first, including remote ones you haven't checked out.

Type a directory's name on its own to `cd` into it. `cd -` then `Tab` lists where you've been this session.

## Uninstall

```sh
brew uninstall zao
```

