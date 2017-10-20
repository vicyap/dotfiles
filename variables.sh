#!/bin/bash
# shellcheck disable=SC2034

ANSIBLE_INVENTORY_FILE='./ansible/hosts'
ANSIBLE_PLAYBOOK_FILE='./ansible/dev.yml'
ANSIBLE_CONNECTION_TYPE='local'
ANSIBLE_NUM_FORKS='1'

SHELLCHECK_FILES='ansible_install.sh ansible_check.sh variables.sh'
