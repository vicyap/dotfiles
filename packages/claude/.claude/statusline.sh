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
    if ! git -c core.useBuiltinFSMonitor=false --no-optional-locks diff --quiet HEAD 2>/dev/null; then
        dirty="●"
    elif [ -n "$(git -c core.useBuiltinFSMonitor=false --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
        dirty="+"
    fi
    printf ' [%s%s]' "$branch" "$dirty"
fi

# Model name from JSON input (cyan color)
model=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model" ]; then
    printf ' \033[01;36m[%s]\033[00m' "$model"
fi

# Context USED percentage from JSON input (magenta color)
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx" ]; then
    printf ' \033[01;35m[ctx %.0f%%]\033[00m' "$ctx"
fi

# Rate limit usage from built-in rate_limits field (available for Claude.ai subscribers)
IFS=$'\t' read -r five_pct five_resets seven_pct seven_resets < <(
    echo "$input" | jq -r '[
        (.rate_limits.five_hour.used_percentage // ""),
        (.rate_limits.five_hour.resets_at // ""),
        (.rate_limits.seven_day.used_percentage // ""),
        (.rate_limits.seven_day.resets_at // "")
    ] | @tsv' 2>/dev/null
)
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
