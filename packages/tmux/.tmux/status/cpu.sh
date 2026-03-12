#!/usr/bin/env bash
set -e

CACHE="/tmp/tmux-cpu-${USER}"

case "$(uname -s)" in
    Linux)
        read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        busy=$((total - idle - iowait))

        if [[ -f "$CACHE" ]]; then
            read -r prev_total prev_busy <"$CACHE" || true
            delta_total=$((total - prev_total))
            delta_busy=$((busy - prev_busy))
            if ((delta_total > 0)); then
                pct=$((100 * delta_busy / delta_total))
                ((pct > 99)) && pct=99
            else
                pct=0
            fi
        else
            pct=0
        fi

        printf '%d %d' "$total" "$busy" >"$CACHE"
        printf '%2d%%' "$pct"
        ;;
    Darwin)
        cores=$(sysctl -n hw.logicalcpu)
        ps -A -o %cpu | awk -v cores="$cores" '{sum += $1} END { p = sum / cores; if (p > 99) p = 99; printf "%2d%%", p }'
        ;;
esac
