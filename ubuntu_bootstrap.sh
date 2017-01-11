#!/bin/bash

set -e

DEBIAN_FRONTEND=noninteractive 

PROGRAMS=(stow xorg i3 rxvt-unicode vim task tmux zsh python-pip)
PACKAGES=(i3 i3status Xresources urxvt vim tmux virtualenvs wallpaper zsh)
PIP_PACKAGES=(autoenv virtualenv virtualenvwrapper git+https://github.com/ultrabug/py3status)

sudo apt-get update
sudo apt-get -y install ${PROGRAMS[*]}
sudo pip install ${PIP_PACKAGES[*]}
stow ${PACKAGES[*]}

xrdb $HOME/.Xresources
./install_oh_my_zsh.sh
