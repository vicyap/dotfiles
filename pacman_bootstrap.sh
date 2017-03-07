#!/bin/bash

set -e

PROGRAMS=(acpi arandr dmenu numix-gtk-theme stow xorg-server xorg-xinit i3 rxvt-unicode vim task tmux zsh python-pip)

sudo pacman -Syu --noconfirm
sudo pacman -Sy --noconfirm ${PROGRAMS[*]}
./pip_install.sh
rm -f ~/.virtualenvs/postactivate
rm -f ~/.virtualenvs/postdeactivate
./stow_packages.sh

git clone git://github.com/yonchu/zsh-vcs-prompt.git ~/.zsh/custom/zsh-vcs-prompt

./install_oh_my_zsh.sh
xrdb $HOME/.Xresources
