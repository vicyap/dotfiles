#!/bin/bash

set -e

sudo -v

DEBIAN_FRONTEND=noninteractive 

PROGRAMS=(stow xorg i3 rxvt-unicode vim tmux zsh python-pip)
PACKAGES=(i3 i3status Xresources uxrvt vim tmux virtualenvs wallpaper zsh)
PIP_PACKAGES=(autoenv virtualenv virtualenvwrapper)

sudo apt-get update
sudo apt-get -y install ${PROGRAMS[*]}
pip install ${PIP_PACKAGES[*]} --user
sudo pip install git+https://github.com/ultrabug/py3status
stow ${PACKAGES[*]}

xrdb $HOME/.Xresources
echo "You may have to restart apps or reload configs to take effect"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
