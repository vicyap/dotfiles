#!/bin/bash

# SUDO_PIP_PACKAGES=(git+https://github.com/ultrabug/py3status)
USER_PIP_PACKAGES=(virtualenv virtualenvwrapper)

# sudo pip install ${SUDO_PIP_PACKAGES[*]}
pip install ${USER_PIP_PACKAGES[*]} --user
