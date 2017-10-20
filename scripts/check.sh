#!/bin/bash

set -x
set -e

source ./variables.sh

ansible-playbook \
    --syntax-check \
    --inventory "$ANSIBLE_INVENTORY_FILE" \
    "$ANSIBLE_PLAYBOOK_FILE"

# shellcheck disable=SC2086
shellcheck $SHELLCHECK_FILES
