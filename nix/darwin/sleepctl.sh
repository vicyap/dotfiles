#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: sleepctl off | on | status\n' >&2
    exit 1
}

[[ $# == 1 ]] || usage

case "$1" in
    off) /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 1 ;;
    on) /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 ;;
    status) ;;
    *) usage ;;
esac

if /usr/bin/pmset -g | /usr/bin/grep -Eq '^ *SleepDisabled[[:space:]]+1$'; then
    printf 'Sleep is off: the lid can be closed without sleeping.\n\n'
else
    printf 'Sleep is on: normal sleep behavior.\n\n'
fi
/usr/bin/pmset -g
