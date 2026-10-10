#!/usr/bin/env bash
set -euo pipefail

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
state="$HOME/Library/Application Support/Keep Awake"
service=system/org.nixos.keep-awake
umask 077

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

valid_minutes() {
    [[ "$1" =~ ^[0-9]{1,9}$ ]] && ((10#$1 > 0))
}

service_pid() {
    /bin/launchctl print "$service" 2>/dev/null | /usr/bin/awk '$1 == "pid" && $2 == "=" {print $3}'
}

restore_sleep() {
    /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0
    deadline=0
}

cleanup_daemon() {
    rm -f "$state/daemon.pid"
    restore_sleep
}

run_daemon() {
    [[ "$(service_pid)" == "$$" ]] || fail 'The timer must run through launchd.'
    mkdir -p "$state"
    rm -f "$state/daemon.pid"
    deadline=0
    trap cleanup_daemon EXIT
    trap 'exit 0' HUP INT TERM
    restore_sleep
    printf '%s\n' "$$" >"$state/daemon.pid"
    shopt -s nullglob

    while true; do
        if ((deadline > 0 && $(date +%s) >= deadline)); then
            restore_sleep
        fi
        for request in "$state"/request.*; do
            [[ -f "$request/ready" ]] || continue
            local command minutes generation expires result message
            read -r command <"$request/command"
            read -r minutes <"$request/minutes"
            read -r generation <"$request/generation"
            read -r expires <"$request/expires"
            rm -f "$request/ready"
            result=0
            message=inactive
            if [[ "$generation" != "$$" ]] || (($(date +%s) >= expires)); then
                result=1
                message='The timer restarted or the request expired. Try again.'
            else
                if ((deadline > 0 && $(date +%s) >= deadline)); then
                    restore_sleep
                fi
                case "$command" in
                    start)
                        if ! valid_minutes "$minutes"; then
                            result=1
                            message='Enter a positive whole number of minutes (up to nine digits).'
                        elif ((deadline > 0)); then
                            result=1
                            message='Keep Awake is already active. Click again to stop it.'
                        else
                            deadline=$(($(date +%s) + 10#$minutes * 60))
                            /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 1
                        fi
                        ;;
                    stop) restore_sleep ;;
                    status) ;;
                    *)
                        result=1
                        message='Unknown timer command.'
                        ;;
                esac
                if ((result == 0 && deadline > 0)); then
                    message="active $(date -r "$deadline" '+%Y-%m-%d %H:%M:%S %Z')"
                fi
            fi
            # The client may have cancelled while this request was running.
            if [[ -d "$request" ]]; then
                printf '%s\n%s\n' "$result" "$message" >"$request/response.tmp"
                mv "$request/response.tmp" "$request/response"
            fi
        done
        sleep 5 &
        wait "$!"
    done
}

send_request() {
    local pid request result
    [[ -f "$state/daemon.pid" ]] || fail 'Keep Awake timer is unavailable.'
    read -r pid <"$state/daemon.pid"
    [[ "$pid" =~ ^[0-9]+$ && "$(service_pid)" == "$pid" ]] \
        || fail 'Keep Awake timer is unavailable.'
    kill -0 "$pid" 2>/dev/null || fail 'Keep Awake timer is unavailable.'
    request=$(mktemp -d "$state/request.XXXXXXXX")
    trap 'rm -rf "$request"' EXIT
    trap 'exit 1' HUP INT TERM
    printf '%s\n' "$1" >"$request/command"
    printf '%s\n' "${2:-0}" >"$request/minutes"
    printf '%s\n' "$pid" >"$request/generation"
    printf '%s\n' "$(($(date +%s) + 15))" >"$request/expires"
    touch "$request/ready"
    for ((attempt = 0; attempt < 20; attempt++)); do
        if [[ -f "$request/response" ]]; then
            read -r result <"$request/response"
            if [[ "$result" == 0 ]]; then
                tail -n +2 "$request/response"
            else
                tail -n +2 "$request/response" >&2
            fi
            exit "$result"
        fi
        [[ "$(service_pid)" == "$pid" ]] || fail 'Keep Awake timer stopped. Try again.'
        sleep 1
    done
    fail 'Keep Awake timer did not respond. Try again.'
}

case "${1:-}" in
    daemon)
        [[ $# == 1 ]] || fail 'Usage: helper daemon'
        run_daemon
        ;;
    start)
        if [[ $# != 2 ]] || ! valid_minutes "$2"; then
            fail 'Enter a positive whole number of minutes (up to nine digits).'
        fi
        send_request start "$2"
        ;;
    stop | status)
        [[ $# == 1 ]] || fail 'Usage: helper start MINUTES | stop | status'
        send_request "$1"
        ;;
    *) fail 'Usage: helper start MINUTES | stop | status' ;;
esac
