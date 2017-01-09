#!/bin/bash

set -e

sudo -v

DEBIAN_FRONTEND=noninteractive 

PROGRAMS=(stow xorg i3 rxvt-unicode vim tmux zsh)
PACKAGES=(i3 i3status Xresources uxrvt vim tmux zsh)

sudo apt-get update
sudo apt-get -y install ${PROGRAMS[*]}
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
stow ${PACKAGES[*]}

xrdb $HOME/.Xresources
echo "You may have to restart apps or reload configs to take effect"
