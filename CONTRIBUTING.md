## Development

Run zao from a checkout by putting its `bin/zao` on your `PATH`. `zao init` then loads the checkout's `config/`:

```sh
ln -s "$PWD/bin/zao" ~/.local/bin/zao
```

Install dependencies:

```sh
brew install fzf zoxide zsh-autosuggestions zsh-syntax-highlighting shellcheck
```

Changes take effect in a new shell. To try zao without changing your own `~/.zshrc`:

```sh
mkdir -p /tmp/zao && echo 'eval "$(zao init)"' > /tmp/zao/.zshrc && ZDOTDIR=/tmp/zao zsh
```

Run the tests, which start zao in a real interactive shell and type into it:

```sh
zsh .github/test.zsh
```

To release, set the new version in `config/VERSION`, commit, then tag and push:

```sh
git tag -a v0.2.0 -m "zao 0.2.0" && git push origin main v0.2.0
```

The release workflow creates the GitHub release and points the [Homebrew formula](https://github.com/drewradcliff/homebrew-tap) at it.
