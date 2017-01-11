#!/bin/bash

set -e

DEBIAN_FRONTEND=noninteractive 

PROGRAMS=(stow xorg i3 rxvt-unicode vim task tmux zsh python-pip)
PIP_PACKAGES=(autoenv virtualenv virtualenvwrapper git+https://github.com/ultrabug/py3status)

sudo apt-get update
sudo apt-get -y install ${PROGRAMS[*]}
sudo pip install ${PIP_PACKAGES[*]}
rm ~/.virtualenvs/postactivate
rm ~/.virtualenvs/postdeactivate
./stow_packages.sh

./install_oh_my_zsh.sh
xrdb $HOME/.Xresources
