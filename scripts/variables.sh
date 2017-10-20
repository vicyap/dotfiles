#!/bin/bash
# shellcheck disable=SC2034

ANSIBLE_INVENTORY_FILE='../ansible/inventory'
ANSIBLE_PLAYBOOK_FILE='../ansible/playbook.yml'
ANSIBLE_CONNECTION_TYPE='local'
ANSIBLE_NUM_FORKS='1'

SHELLCHECK_FILES='deploy.sh install.sh check.sh variables.sh'
