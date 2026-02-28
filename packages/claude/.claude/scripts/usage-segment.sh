#!/bin/bash
# usage-segment.sh — Claude Code rate limit statusline segment
#
# Fetches 5-hour and 7-day utilization from the Anthropic OAuth API.
# Caches responses to avoid hitting the API on every statusline render.
# Outputs a single-line formatted string for statusline integration.
# Exits silently (no output) on any error, expired token, or missing data.
#
# Dependencies: jq, curl
# Platform: Linux (GNU coreutils for `date -d` and `stat -c`)

CACHE_DIR="${XDG_CACHE_DIR:-$HOME/.cache}/claude-code"
CACHE_FILE="$CACHE_DIR/usage.json"
CACHE_TTL=60
CREDS_FILE="$HOME/.claude/.credentials.json"
API_URL="https://api.anthropic.com/api/oauth/usage"

# ANSI colors
RED=$'\033[0;31m'
BOLD_RED=$'\033[1;31m'
YELLOW=$'\033[0;33m'
GREEN=$'\033[0;32m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# Color a utilization percentage by severity threshold.
#   <50% green, 50-74% yellow, 75-89% red, >=90% bold red
color_util() {
    local pct=$1 color
    if (( pct >= 90 )); then
        color=$BOLD_RED
    elif (( pct >= 75 )); then
        color=$RED
    elif (( pct >= 50 )); then
        color=$YELLOW
    else
        color=$GREEN
    fi
    printf '%s' "${color}${pct}%${RESET}"
}

# Format seconds as a Go-style duration string (e.g., 5d 3h 24m).
# Minute granularity. Omits zero-value larger units.
format_duration() {
    local seconds=$1
    if (( seconds <= 0 )); then
        printf '%s' "0m"
        return
    fi
    local days=$(( seconds / 86400 ))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local result=""
    (( days > 0 )) && result="${days}d "
    (( hours > 0 )) && result="${result}${hours}h "
    result="${result}${minutes}m"
    printf '%s' "$result"
}

# --- Fetch and cache ---

mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

refresh=true
if [[ -f "$CACHE_FILE" ]]; then
    cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null) || cache_mtime=0
    cache_age=$(( $(date +%s) - cache_mtime ))
    (( cache_age < CACHE_TTL )) && refresh=false
fi

if $refresh; then
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS_FILE" 2>/dev/null)
    [[ -z "$token" ]] && exit 0

    expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$CREDS_FILE" 2>/dev/null)
    now_ms=$(( $(date +%s) * 1000 ))
    (( expires_at <= now_ms )) && exit 0

    if response=$(curl -sf -m 5 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "$API_URL" 2>/dev/null); then
        printf '%s' "$response" > "$CACHE_FILE"
    fi
fi

# --- Parse and format ---

[[ -f "$CACHE_FILE" ]] || exit 0

# Single jq call: extract all four values as tab-separated fields
IFS=$'\t' read -r five_util five_resets seven_util seven_resets < <(
    jq -r '[
        (.five_hour.utilization // ""),
        (.five_hour.resets_at // ""),
        (.seven_day.utilization // ""),
        (.seven_day.resets_at // "")
    ] | @tsv' "$CACHE_FILE" 2>/dev/null
)

[[ -z "$five_util" || -z "$seven_util" ]] && exit 0

# Round utilization to integers
five_int=$(printf '%.0f' "$five_util" 2>/dev/null) || exit 0
seven_int=$(printf '%.0f' "$seven_util" 2>/dev/null) || exit 0

# Calculate time remaining from reset timestamps
now=$(date +%s)
five_reset_epoch=$(date -d "$five_resets" +%s 2>/dev/null) || exit 0
seven_reset_epoch=$(date -d "$seven_resets" +%s 2>/dev/null) || exit 0

five_remaining=$(( five_reset_epoch - now ))
(( five_remaining < 0 )) && five_remaining=0
seven_remaining=$(( seven_reset_epoch - now ))
(( seven_remaining < 0 )) && seven_remaining=0

# Build output string, then emit once
five_color=$(color_util "$five_int")
five_dur=$(format_duration "$five_remaining")
seven_color=$(color_util "$seven_int")
seven_dur=$(format_duration "$seven_remaining")

printf '%s' "5h: ${five_color} ${DIM}(${five_dur})${RESET} 7d: ${seven_color} ${DIM}(${seven_dur})${RESET}"
