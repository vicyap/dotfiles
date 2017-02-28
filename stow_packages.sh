#!/bin/bash

set -e
set -x

PACKAGES=(i3 i3status Xresources urxvt vim tmux virtualenvs wallpaper zsh)

POTENTIAL_CONFLICTS=(\
    $HOME/.virtualenvs/postactivate\
    $HOME/.virtualenvs/postdeactivate\
    $HOME/.config/i3/config)

for FILE in ${POTENTIAL_CONFLICTS[@]}
do
    if test -f $FILE; then mv $FILE $FILE.copy; fi
done

stow ${PACKAGES[*]} --verbose=2
