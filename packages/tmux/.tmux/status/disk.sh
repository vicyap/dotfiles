#!/usr/bin/env bash
set -e

case "$(uname -s)" in
    Darwin)
        df -h / | awk 'NR==2 {
            unit = $4; gsub(/[0-9.]/, "", unit)
            printf "%.0f%s free", $4 + 0, unit
        }'
        ;;
    Linux)
        df -h / | awk 'NR==2 { printf "%s free", $4 }'
        ;;
esac
