#!/usr/bin/env bash
set -euo pipefail

export HOME=/opt/data
export HERMES_HOME=/opt/data

python_bin=/opt/hermes/.venv/bin/python
pilot_dir=/opt/hermes-pilot
marker_dir="$HERMES_HOME/data"
backup_marker="$marker_dir/last_cloud_backup_date"
last_reconcile=0
mkdir -p "$marker_dir"

while true; do
    now_epoch="$(date +%s)"
    if ((now_epoch - last_reconcile >= 900)); then
        if ! "$python_bin" "$pilot_dir/training_reminder_dispatcher.py" reconcile --quiet; then
            echo "training reconciler failed; durable outbox will retry" >&2
        fi
        last_reconcile="$now_epoch"
    fi

    pacific_date="$(date +%F)"
    pacific_clock="$(date +%H%M)"
    last_backup="$(test -f "$backup_marker" && head -n 1 "$backup_marker" || true)"
    if ((10#$pacific_clock > 429)) && [[ "$last_backup" != "$pacific_date" ]]; then
        if "$python_bin" "$pilot_dir/backup_to_tigris.py"; then
            marker_tmp="${backup_marker}.$$"
            printf '%s\n' "$pacific_date" >"$marker_tmp"
            mv "$marker_tmp" "$backup_marker"
        else
            echo "daily Hermes backup failed; retrying on the next loop" >&2
        fi
    fi

    sleep 60
done
