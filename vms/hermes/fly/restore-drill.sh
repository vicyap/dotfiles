#!/usr/bin/env bash
set -euo pipefail

hermes_revision=7426c09beee73bdff94d916015bac71384f6bc92
pilot_image_tag="$hermes_revision-pilot6"
app_name="${HERMES_APP:-the1000club-hermes}"
backup_key="${1:-}"
image="registry.fly.io/$app_name:$pilot_image_tag"

for command_name in fly jq; do
    command -v "$command_name" >/dev/null || {
        echo "Missing required command: $command_name" >&2
        exit 1
    }
done

volume_json="$(fly volumes create hermes_restore_drill \
    --app "$app_name" \
    --region sjc \
    --size 5 \
    --snapshot-retention 1 \
    --scheduled-snapshots=false \
    --json \
    --yes)"
volume_id="$(jq -r '.id // .[0].id' <<<"$volume_json")"
if [[ -z "$volume_id" || "$volume_id" == null ]]; then
    echo "Unable to determine restore-drill volume ID" >&2
    exit 1
fi
machine_name="hermes-restore-drill-$(date -u +%s)-$$"
machine_id=

cleanup() {
    if [[ -z "$machine_id" ]]; then
        machine_id="$(fly machine list --app "$app_name" --json 2>/dev/null \
            | jq -r --arg name "$machine_name" '.[] | select(.name == $name) | .id' \
            | head -n 1)" || true
    fi
    if [[ -n "$machine_id" ]]; then
        fly machine destroy "$machine_id" --app "$app_name" --force >/dev/null 2>&1 || true
    fi
    if [[ -n "$volume_id" ]]; then
        echo "Restore drill failed; retained volume $volume_id for inspection." >&2
    fi
}
trap cleanup EXIT

if [[ -n "$backup_key" ]]; then
    [[ "$backup_key" =~ ^[A-Za-z0-9._/-]+$ ]] || {
        echo "Invalid backup object key" >&2
        exit 1
    }
fi

fly machine run "$image" "3600" \
    --app "$app_name" \
    --region sjc \
    --name "$machine_name" \
    --volume "$volume_id:/opt/data" \
    --entrypoint /bin/sleep \
    --detach \
    --restart no \
    --vm-cpu-kind shared \
    --vm-cpus 1 \
    --vm-memory 2048 >/dev/null
machine_id="$(fly machine list --app "$app_name" --json \
    | jq -r --arg name "$machine_name" '.[] | select(.name == $name) | .id')"
[[ -n "$machine_id" ]] || {
    echo "Unable to determine restore-drill Machine ID" >&2
    exit 1
}

restore_command="/opt/hermes/.venv/bin/python /opt/hermes-pilot/restore_backup.py"
if [[ -n "$backup_key" ]]; then
    restore_command+=" --key $backup_key"
fi
fly ssh console \
    --app "$app_name" \
    --machine "$machine_id" \
    --user root \
    --command "chown -R hermes:hermes /opt/data"
fly ssh console \
    --app "$app_name" \
    --machine "$machine_id" \
    --user hermes \
    --command "$restore_command"

fly machine destroy "$machine_id" --app "$app_name" --force >/dev/null
machine_id=
for _ in {1..30}; do
    attached_machine="$(fly volumes list --app "$app_name" --json \
        | jq -r --arg id "$volume_id" '.[] | select(.id == $id) | .attached_machine_id // .attached_alloc_id // empty')"
    [[ -z "$attached_machine" ]] && break
    sleep 1
done
[[ -z "$attached_machine" ]] || {
    echo "Restore-drill volume did not detach from $attached_machine" >&2
    exit 1
}
fly volumes destroy "$volume_id" --app "$app_name" --yes
volume_id=
trap - EXIT
