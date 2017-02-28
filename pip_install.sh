#!/bin/bash

PIP_PACKAGES=(virtualenv virtualenvwrapper git+https://github.com/ultrabug/py3status)

pip install ${PIP_PACKAGES[*]} --user
