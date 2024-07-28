# https://gitlab.com/gnachman/iterm2/-/wikis/tmux-Integration-Best-Practices#how-do-i-use-shell-integration
export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=YES
if [ -n "$ZSH_VERSION" ]; then
    test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi