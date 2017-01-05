#!/bin/bash

set -e

sudo -v

DEBIAN_FRONTEND=noninteractive 

PROGRAMS=(stow xorg i3 rxvt-unicode vim)
PACKAGES=(i3 i3status Xresources uxrvt vim)

sudo apt-get update
sudo apt-get -y install ${PROGRAMS[*]}
stow ${PACKAGES[*]}

xrdb $HOME/.Xresources
echo "You may have to restart apps or reload configs to take effect"
