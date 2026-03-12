#!/usr/bin/env bash
set -e

# NVIDIA GPU (Linux typically)
if command -v nvidia-smi &>/dev/null; then
    pct=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
    if [[ -n "$pct" ]]; then
        printf '%s%%' "$pct"
        exit 0
    fi
fi

# No accessible GPU metrics — output nothing
