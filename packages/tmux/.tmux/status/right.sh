#!/usr/bin/env bash
set -e

STATUS_DIR="${HOME}/.tmux/status"

segments=()
segments+=("CPU $("$STATUS_DIR/cpu.sh" 2>/dev/null)")
segments+=("MEM $("$STATUS_DIR/memory.sh" 2>/dev/null)")
segments+=("DSK $("$STATUS_DIR/disk.sh" 2>/dev/null)")
segments+=("NET $("$STATUS_DIR/network.sh" 2>/dev/null)")

gpu=$("$STATUS_DIR/gpu.sh" 2>/dev/null)
[[ -n "$gpu" ]] && segments+=("GPU $gpu")

battery=$("$STATUS_DIR/battery.sh" 2>/dev/null)
[[ -n "$battery" ]] && segments+=("BAT $battery")

segments+=("$("$STATUS_DIR/clock.sh" 2>/dev/null)")

# Join with separator
first=true
for seg in "${segments[@]}"; do
    [[ -z "$seg" ]] && continue
    if $first; then
        first=false
    else
        printf ' │ '
    fi
    printf '%s' "$seg"
done
