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

# Model, context USED percentage, and rate limit usage from JSON input
IFS=$'\t' read -r model ctx five_pct five_resets seven_pct seven_resets < <(
    echo "$input" | jq -r '[
        (.model.display_name // ""),
        (.context_window.used_percentage // ""),
        (.rate_limits.five_hour.used_percentage // ""),
        (.rate_limits.five_hour.resets_at // ""),
        (.rate_limits.seven_day.used_percentage // ""),
        (.rate_limits.seven_day.resets_at // "")
    ] | @tsv' 2>/dev/null
)

# Model name (cyan color)
if [ -n "$model" ]; then
    printf ' \033[01;36m[%s]\033[00m' "$model"
fi

# Context USED percentage (magenta color)
if [ -n "$ctx" ]; then
    printf ' \033[01;35m[ctx %.0f%%]\033[00m' "$ctx"
fi

# Rate limit usage from built-in rate_limits field (available for Claude.ai subscribers)
if [ -n "$five_pct" ] && [ -n "$seven_pct" ]; then
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
    five_rem=$((${five_resets%.*} - now))
    ((five_rem < 0)) && five_rem=0
    seven_rem=$((${seven_resets%.*} - now))
    ((seven_rem < 0)) && seven_rem=0
    printf ' 5h: \033[0;32m%.0f%%\033[0m \033[2m(%s)\033[0m 7d: \033[0;32m%.0f%%\033[0m \033[2m(%s)\033[0m' \
        "$five_pct" "$(format_duration "$five_rem")" \
        "$seven_pct" "$(format_duration "$seven_rem")"
fi
