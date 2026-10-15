#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Hostname (bright green); user and branch are omitted as redundant.
printf '\033[01;92m%s\033[00m' "$(hostname -s)"

# Location (bright blue): repo name, plus ":<worktree>" inside a linked
# worktree; the directory name outside a git repo.
top=$(git --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
if [ -n "$top" ]; then
    common=$(git --no-optional-locks rev-parse --path-format=absolute --git-common-dir)
    main=$(dirname "$common")
    location=$(basename "$main")
    [ "$top" != "$main" ] && location="$location:$(basename "$top")"
else
    location=$(basename "$PWD")
fi
printf '  \033[01;94m%s\033[00m' "$location"

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

# Color a percentage by level: bright green below 80, yellow below 95, red beyond.
pct() {
    local n color=92
    printf -v n '%.0f' "$1"
    ((n >= 80)) && color=93
    ((n >= 95)) && color=91
    printf '\033[0;%sm%s%%\033[0m' "$color" "$n"
}

# Model name (bright cyan)
if [ -n "$model" ]; then
    printf '  \033[01;96m%s\033[00m' "$model"
fi

# Context USED percentage
if is_pct "$ctx"; then
    printf '  🪟 %s' "$(pct "$ctx")"
fi

# Rate limit usage from built-in rate_limits field (available for Claude.ai
# subscribers). Rendered only once both windows report a sane percentage.
if is_pct "$five_pct" && is_pct "$seven_pct"; then
    now=$(date +%s)
    # Two largest units: 2d10h, 3h6m, 42m.
    format_duration() {
        local s=$1
        ((s < 0)) && s=0
        local d=$((s / 86400)) h=$(((s % 86400) / 3600)) m=$(((s % 3600) / 60))
        if ((d > 0)); then
            printf '%dd%dh' "$d" "$h"
        elif ((h > 0)); then
            printf '%dh%dm' "$h" "$m"
        else
            printf '%dm' "$m"
        fi
    }
    reset_label() {
        is_epoch "$1" || {
            printf '?'
            return
        }
        format_duration $(($1 - now))
    }
    printf '  ⏳ %s %s  📅 %s %s' \
        "$(pct "$five_pct")" "$(reset_label "$five_resets")" \
        "$(pct "$seven_pct")" "$(reset_label "$seven_resets")"
fi
