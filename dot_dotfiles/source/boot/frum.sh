export PATH="/var/folders/f8/8y3wv_qd11s7w0l0wfr0tbv40000gn/T/frum_6690_1685191278832/bin":$PATH
export FRUM_MULTISHELL_PATH="/var/folders/f8/8y3wv_qd11s7w0l0wfr0tbv40000gn/T/frum_6690_1685191278832"
export FRUM_DIR="/Users/agusman/.frum"
export FRUM_LOGLEVEL="info"
export FRUM_RUBY_BUILD_MIRROR="https://cache.ruby-lang.org/pub/ruby"
autoload -U add-zsh-hook
_frum_autoload_hook () {
    frum --log-level quiet local
}

add-zsh-hook chpwd _frum_autoload_hook \
    && _frum_autoload_hook


