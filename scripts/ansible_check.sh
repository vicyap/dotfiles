#!/bin/bash

set -x
set -e

source variables.sh

ansible-playbook \
    --syntax-check \
    --inventory-file ${ANSIBLE_INVENTORY_FILE} \
    ${ANSIBLE_PLAYBOOK_FILE}

shellcheck ./*.sh