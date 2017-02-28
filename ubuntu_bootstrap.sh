#!/bin/bash

set -e

DEBIAN_FRONTEND=noninteractive 

PROGRAMS=(acpi stow xorg i3 rxvt-unicode vim task tmux zsh python-pip)
PIP_PACKAGES=(autoenv virtualenv virtualenvwrapper git+https://github.com/ultrabug/py3status)

sudo apt-get update
sudo apt-get -y install ${PROGRAMS[*]}
./pip_install.sh
rm -f ~/.virtualenvs/postactivate
rm -f ~/.virtualenvs/postdeactivate
./stow_packages.sh

git clone git://github.com/yonchu/zsh-vcs-prompt.git ~/.zsh/custom/zsh-vcs-prompt

./install_oh_my_zsh.sh
xrdb $HOME/.Xresources
