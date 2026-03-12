#!/usr/bin/env bash
set -e

CACHE="/tmp/tmux-net-${USER}"

now=$(date +%s)

case "$(uname -s)" in
    Linux)
        # Sum all non-loopback interface bytes
        rx_bytes=0
        tx_bytes=0
        while IFS=': ' read -r iface rest; do
            iface=$(echo "$iface" | tr -d ' ')
            [[ "$iface" == "lo" ]] && continue
            [[ -z "$iface" ]] && continue
            read -r rb _ _ _ _ _ _ _ tb _ <<<"$rest"
            rx_bytes=$((rx_bytes + rb))
            tx_bytes=$((tx_bytes + tb))
        done < <(tail -n +3 /proc/net/dev)
        ;;
    Darwin)
        # Sum bytes across all active network interfaces
        eval "$(netstat -ib 2>/dev/null | awk '
            NR > 1 && $1 !~ /^lo/ && $4 ~ /\./ {
                rx += $7; tx += $10
            }
            END { printf "rx_bytes=%d\ntx_bytes=%d\n", rx, tx }
        ')"
        ;;
esac

if [[ -f "$CACHE" ]]; then
    read -r prev_time prev_rx prev_tx <"$CACHE" || true
    elapsed=$((now - prev_time))
    if ((elapsed > 0)); then
        rx_rate=$(((rx_bytes - prev_rx) / elapsed))
        tx_rate=$(((tx_bytes - prev_tx) / elapsed))
    else
        rx_rate=0
        tx_rate=0
    fi
else
    rx_rate=0
    tx_rate=0
fi

printf '%d %d %d' "$now" "$rx_bytes" "$tx_bytes" >"$CACHE"

format_rate() {
    local rate=$1
    if ((rate >= 1073741824)); then
        awk -v r="$rate" 'BEGIN { printf "%5.1fG", r/1073741824 }'
    elif ((rate >= 1048576)); then
        awk -v r="$rate" 'BEGIN { printf "%5.1fM", r/1048576 }'
    elif ((rate >= 1024)); then
        awk -v r="$rate" 'BEGIN { printf "%5.1fK", r/1024 }'
    else
        awk -v r="$rate" 'BEGIN { printf "%5.1fB", r }'
    fi
}

printf '↑%s ↓%s' "$(format_rate "$tx_rate")" "$(format_rate "$rx_rate")"
