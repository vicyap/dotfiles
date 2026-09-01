#!/usr/bin/env bash
set -euo pipefail

hermes_revision=7426c09beee73bdff94d916015bac71384f6bc92
pilot_image_tag="$hermes_revision-pilot6"
app_name="${HERMES_APP:-the1000club-hermes}"
backup_key="${1:?usage: stage-restore.sh OBJECT_KEY}"
image="registry.fly.io/$app_name:$pilot_image_tag"

[[ "$backup_key" =~ ^[A-Za-z0-9._/-]+$ ]] || {
    echo "Invalid backup object key" >&2
    exit 1
}

volume_json="$(fly volumes list --app "$app_name" --json \
    | jq --exit-status '[.[] | select(.name == "hermes_data")] | if length == 1 then .[0] else error("expected one hermes_data volume") end')"
volume_id="$(jq -r '.id' <<<"$volume_json")"
attached_machine="$(jq -r '.attached_machine_id // .attached_alloc_id // empty' <<<"$volume_json")"
if [[ -n "$attached_machine" ]]; then
    echo "Volume $volume_id is attached to $attached_machine; refusing staged restore." >&2
    exit 1
fi
machine_name="hermes-stage-restore-$(date -u +%s)-$$"
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
}
trap cleanup EXIT

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
    echo "Unable to determine staged-restore Machine ID" >&2
    exit 1
}
fly ssh console \
    --app "$app_name" \
    --machine "$machine_id" \
    --user root \
    --command "chown -R hermes:hermes /opt/data"
fly ssh console \
    --app "$app_name" \
    --machine "$machine_id" \
    --user hermes \
    --command "/opt/hermes/.venv/bin/python /opt/hermes-pilot/restore_backup.py --key $backup_key"

fly machine destroy "$machine_id" --app "$app_name" --force >/dev/null
machine_id=
for _ in {1..30}; do
    attached_machine="$(fly volumes list --app "$app_name" --json \
        | jq -r --arg id "$volume_id" '.[] | select(.id == $id) | .attached_machine_id // .attached_alloc_id // empty')"
    [[ -z "$attached_machine" ]] && break
    sleep 1
done
[[ -z "$attached_machine" ]] || {
    echo "Production volume did not detach from $attached_machine" >&2
    exit 1
}
trap - EXIT

printf 'Restored %s into %s.\n' "$backup_key" "$volume_id"
