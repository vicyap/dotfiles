#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME"
helper="$repo/nix/darwin/keep-awake.sh"

expect_failure() {
    local expected="$1"
    shift
    if bash "$helper" "$@" >"$tmp/output" 2>&1; then
        printf 'FAIL: command unexpectedly succeeded: %s\n' "$*" >&2
        exit 1
    fi
    if [[ "$(cat "$tmp/output")" != *"$expected"* ]]; then
        cat "$tmp/output" >&2
        exit 1
    fi
}

for minutes in '' 0 00 -1 1.5 ' 5' abc 1000000000 '1; touch injected'; do
    expect_failure 'positive whole number' start "$minutes"
done
expect_failure 'positive whole number' start
expect_failure 'positive whole number' start 1 extra
expect_failure 'Usage:' stop extra
expect_failure 'Usage:' status extra
expect_failure 'Usage:' unknown
expect_failure 'timer is unavailable' start 1
expect_failure 'timer is unavailable' start 01
expect_failure 'timer is unavailable' start 999999999
expect_failure 'timer is unavailable' stop
expect_failure 'timer is unavailable' status
[[ ! -e "$HOME/Library/Application Support/Keep Awake" ]]
mkdir -p "$HOME/Library/Application Support/Keep Awake"
printf '%s\n' "$$" >"$HOME/Library/Application Support/Keep Awake/daemon.pid"
expect_failure 'timer is unavailable' start 1
expect_failure 'timer is unavailable' status
expect_failure 'must run through launchd' daemon
printf '  ok invalid input, missing timer, and stale daemon identity fail\n'
