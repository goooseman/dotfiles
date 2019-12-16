#!/usr/bin/env bash

# Install Homebrew, if not already installed
which brew > /dev/null || ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install Ansible, if not already installed
which ansible-playbook > /dev/null || brew install ansible

# Install requirements

ansible-galaxy install -r $HOME/.dotfiles/setup/osx_requirements.yml

# Provision machine with ansible

if [ ! -d "~/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi 

if [ -z "$1" ];
then
    : # $1 was not given
    ansible-playbook -i "localhost," -c local --become-method=sudo -K $HOME/.dotfiles/setup/osx.yml
else
    : # $1 was given
    ansible-playbook -i "localhost," -c local --become-method=sudo -K $HOME/.dotfiles/setup/osx.yml --start-at-task "$1"
fi