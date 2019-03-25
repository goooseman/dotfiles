eval "`$HOME/.fnm/fnm env --multi`"

if [ -n "$ZSH_VERSION" ]; then
  # Autoload fnm version, when cd to dir
  autoload -U add-zsh-hook
  load-fnm() {
    if [[ -f .nvmrc && -r .nvmrc ]]; then
      fnm use
    fi
  }
  add-zsh-hook chpwd load-fnm
fi