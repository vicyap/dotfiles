#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Base prompt with colors (green for user@host, blue for directory)
printf '%s\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' \
    "${debian_chroot:+($debian_chroot)}" \
    "$(whoami)" \
    "$(hostname -s)" \
    "${PWD/#$HOME/\~}"

# Git branch with dirty indicator (if in a git repo)
branch=$(git -c core.useBuiltinFSMonitor=false --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
    # Check for uncommitted changes (fast method)
    dirty=""
    status_out=$(git -c core.useBuiltinFSMonitor=false --no-optional-locks status --porcelain 2>/dev/null)
    if [ -n "$status_out" ]; then
        if echo "$status_out" | grep -qv '^??'; then
            dirty="●"
        else
            dirty="+"
        fi
    fi
    printf ' [%s%s]' "$branch" "$dirty"
fi

# Model, context USED percentage, and rate limit usage from JSON input.
# One jq call emits one field per line; a separate `read` per field preserves
# empty lines. A value that is still null at session start (e.g. rate limits
# before they load) stays in its own field instead of collapsing and shifting a
# reset timestamp into a percentage slot, which an IFS=$'\t' split would do.
{
    IFS= read -r model
    IFS= read -r ctx
    IFS= read -r five_pct
    IFS= read -r five_resets
    IFS= read -r seven_pct
    IFS= read -r seven_resets
} < <(
    echo "$input" | jq -r '
        (.model.display_name // ""),
        (.context_window.used_percentage // ""),
        (.rate_limits.five_hour.used_percentage // ""),
        (.rate_limits.five_hour.resets_at // ""),
        (.rate_limits.seven_day.used_percentage // ""),
        (.rate_limits.seven_day.resets_at // "")
    ' 2>/dev/null
)

# A usable percentage is numeric and within 0-100, so a raw reset timestamp can
# never be rendered as a "1783638000%".
is_pct() { [[ $1 =~ ^[0-9]+(\.[0-9]+)?$ ]] && ((${1%.*} <= 100)); }
# A usable reset time is a positive integer (unix epoch seconds).
is_epoch() { [[ $1 =~ ^[0-9]+$ ]]; }

# Model name (cyan color)
if [ -n "$model" ]; then
    printf ' \033[01;36m[%s]\033[00m' "$model"
fi

# Context USED percentage (magenta color)
if is_pct "$ctx"; then
    printf ' \033[01;35m[ctx %.0f%%]\033[00m' "$ctx"
fi

# Rate limit usage from built-in rate_limits field (available for Claude.ai
# subscribers). Rendered only once both windows report a sane percentage.
if is_pct "$five_pct" && is_pct "$seven_pct"; then
    now=$(date +%s)
    format_duration() {
        local s=$1
        ((s <= 0)) && {
            printf '0m'
            return
        }
        local d=$((s / 86400)) h=$(((s % 86400) / 3600)) m=$(((s % 3600) / 60))
        local r=""
        ((d > 0)) && r="${d}d "
        ((h > 0)) && r="${r}${h}h "
        printf '%s' "${r}${m}m"
    }
    reset_label() {
        is_epoch "$1" || {
            printf '?'
            return
        }
        local rem=$(($1 - now))
        ((rem < 0)) && rem=0
        format_duration "$rem"
    }
    printf ' 5h: \033[0;32m%.0f%%\033[0m \033[2m(%s)\033[0m 7d: \033[0;32m%.0f%%\033[0m \033[2m(%s)\033[0m' \
        "$five_pct" "$(reset_label "$five_resets")" \
        "$seven_pct" "$(reset_label "$seven_resets")"
fi
