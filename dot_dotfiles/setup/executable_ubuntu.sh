#!/usr/bin/env bash

install_ansible () {
    sudo apt-get update
    sudo apt-get install software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt-get install ansible
}

# Install Ansible, if not already installed
which ansible-playbook > /dev/null || install_ansible

# Install requirements

ansible-galaxy install -r $HOME/.dotfiles/setup/ubuntu_requirements.yml

# Get a sudo password in the current shell

sudo echo "I'm a superuser"

# Provision machine with ansible

if [ -z "$1" ];
then
    : # $1 was not given
    ansible-playbook -i "localhost," -c local --become-method=sudo $HOME/.dotfiles/setup/ubuntu.yml
else
    : # $1 was given
    ansible-playbook -i "localhost," -c local --become-method=sudo $HOME/.dotfiles/setup/ubuntu.yml --start-at-task "$1"
fi