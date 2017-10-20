#!/bin/bash

set -x
set -e

source variables.sh

ansible-playbook \
    --forks ${ANSIBLE_NUM_FORKS} \
    --connection ${ANSIBLE_CONNECTION_TYPE} \
    --inventory-file ${ANSIBLE_INVENTORY_FILE} \
    ${ANSIBLE_PLAYBOOK_FILE}
