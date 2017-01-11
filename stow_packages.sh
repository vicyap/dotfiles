#!/bin/bash

set -e

PACKAGES=(i3 i3status Xresources urxvt vim tmux virtualenvs wallpaper zsh)
stow ${PACKAGES[*]} --verbose=2
