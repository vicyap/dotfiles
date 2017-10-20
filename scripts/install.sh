#!/bin/bash

source ./variables.sh

# Install pip
if ! hash pip 2>/dev/null; then
    echo "Installing pip..."
    wget https://bootstrap.pypa.io/get-pip.py 
    python get-pip.py
    rm get-pip.py
fi
pip --version

# Install ansible
if ! hash ansible 2>/dev/null; then
    echo "Installing ansible..."
    pip -q install -r requirements.txt
fi
ansible --version

# Install shellcheck
if [[ "$OSTYPE" == "darwin"* ]]; then
# macOS should not brew install as root
ansible localhost \
    --inventory "$ANSIBLE_INVENTORY_FILE" \
    --connection "$ANSIBLE_CONNECTION_TYPE" \
    --module-name package \
    --args "name=shellcheck state=latest"
    --become --become-user="$SUDO_USER"
else
ansible localhost \
    --inventory "$ANSIBLE_INVENTORY_FILE" \
    --connection "$ANSIBLE_CONNECTION_TYPE" \
    --module-name package \
    --args "name=shellcheck state=latest"
fi
shellcheck --version
