#!/usr/bin/env bash
set -euo pipefail

hermes_revision=7426c09beee73bdff94d916015bac71384f6bc92
pilot_image_tag="$hermes_revision-pilot6"
app_name="${HERMES_APP:-the1000club-hermes}"
backup_path="${1:?usage: upload-backup.sh BACKUP.zip [OBJECT_KEY]}"
backup_path="$(realpath "$backup_path")"
object_key="${2:-migration/$(date -u +%Y-%m-%d-%H%M%S)/$(basename "$backup_path")}"
image="registry.fly.io/$app_name:$pilot_image_tag"
local_image="the1000club-hermes:$hermes_revision"
temporary_directory="$(mktemp -d)"
sanitized_backup="$temporary_directory/hermes-backup.zip"
machine_name="hermes-backup-upload-$(date -u +%s)-$$"
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
    if [[ -f "$sanitized_backup" ]]; then
        unlink "$sanitized_backup"
    fi
    rmdir "$temporary_directory"
}
trap cleanup EXIT

unzip -tq "$backup_path" >/dev/null
[[ "$object_key" =~ ^[A-Za-z0-9._/-]+$ ]] || {
    echo "Invalid backup object key" >&2
    exit 1
}
docker image inspect "$local_image" >/dev/null
docker run --rm \
    --network none \
    --user "$(id -u):$(id -g)" \
    --entrypoint /opt/hermes/.venv/bin/python \
    --volume "$backup_path:/input/hermes-backup.zip:ro" \
    --volume "$temporary_directory:/output" \
    "$local_image" \
    /opt/hermes-pilot/backup_to_tigris.py \
    --sanitize-source /input/hermes-backup.zip \
    --sanitize-destination /output/hermes-backup.zip >/dev/null
unzip -tq "$sanitized_backup" >/dev/null
fly machine run "$image" "3600" \
    --app "$app_name" \
    --region sjc \
    --name "$machine_name" \
    --entrypoint /bin/sleep \
    --detach \
    --restart no \
    --vm-cpu-kind shared \
    --vm-cpus 1 \
    --vm-memory 2048 >/dev/null
machine_id="$(fly machine list --app "$app_name" --json \
    | jq -r --arg name "$machine_name" '.[] | select(.name == $name) | .id')"
[[ -n "$machine_id" ]] || {
    echo "Unable to determine backup upload Machine ID" >&2
    exit 1
}
fly ssh sftp put "$sanitized_backup" /tmp/hermes-backup.zip \
    --app "$app_name" \
    --machine "$machine_id" \
    --mode 0600
fly ssh console \
    --app "$app_name" \
    --machine "$machine_id" \
    --user root \
    --command "/opt/hermes/.venv/bin/python /opt/hermes-pilot/backup_to_tigris.py --source /tmp/hermes-backup.zip --key $object_key"

printf '%s\n' "$object_key"
