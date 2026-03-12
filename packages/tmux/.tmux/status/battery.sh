#!/usr/bin/env bash
set -e

case "$(uname -s)" in
    Darwin)
        pmset_out=$(pmset -g batt 2>/dev/null) || exit 0
        pct=$(echo "$pmset_out" | grep -o '[0-9]*%' | head -1 | tr -d '%')
        [[ -z "$pct" ]] && exit 0

        if echo "$pmset_out" | grep -q 'AC Power'; then
            symbol="+"
        elif ((pct <= 10)); then
            symbol="!"
        else
            symbol=""
        fi
        printf '%s%d%%' "$symbol" "$pct"
        ;;
    Linux)
        bat="/sys/class/power_supply/BAT0"
        [[ -f "$bat/capacity" ]] || exit 0

        pct=$(cat "$bat/capacity")
        status=$(cat "$bat/status" 2>/dev/null || echo "Unknown")

        if [[ "$status" == "Charging" ]]; then
            symbol="+"
        elif ((pct <= 10)); then
            symbol="!"
        else
            symbol=""
        fi
        printf '%s%d%%' "$symbol" "$pct"
        ;;
esac
