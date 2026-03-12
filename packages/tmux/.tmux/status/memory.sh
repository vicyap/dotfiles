#!/usr/bin/env bash
set -e

case "$(uname -s)" in
    Linux)
        while IFS=': ' read -r key value _; do
            case "$key" in
                MemTotal) total_kb=$value ;;
                MemAvailable) avail_kb=$value ;;
            esac
        done </proc/meminfo

        awk -v total="$total_kb" -v avail="$avail_kb" 'BEGIN {
            used_gb = (total - avail) / 1048576
            total_gb = total / 1048576
            printf "%.1f/%.0fG", used_gb, total_gb
        }'
        ;;
    Darwin)
        page_size=$(sysctl -n hw.pagesize)
        total_bytes=$(sysctl -n hw.memsize)

        # vm_stat outputs page counts
        vm_stat_output=$(vm_stat)
        free=$(echo "$vm_stat_output" | awk '/Pages free/ {gsub(/\./, "", $3); print $3}')
        inactive=$(echo "$vm_stat_output" | awk '/Pages inactive/ {gsub(/\./, "", $3); print $3}')
        speculative=$(echo "$vm_stat_output" | awk '/Pages speculative/ {gsub(/\./, "", $3); print $3}')
        purgeable=$(echo "$vm_stat_output" | awk '/Pages purgeable/ {gsub(/\./, "", $3); print $3}')

        awk -v total="$total_bytes" -v free="$free" -v inactive="$inactive" \
            -v spec="$speculative" -v purg="$purgeable" -v ps="$page_size" 'BEGIN {
            avail = (free + inactive + spec + purg) * ps
            used_gb = (total - avail) / 1073741824
            total_gb = total / 1073741824
            printf "%.1f/%.0fG", used_gb, total_gb
        }'
        ;;
esac
