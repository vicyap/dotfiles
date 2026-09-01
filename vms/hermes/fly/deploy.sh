#!/usr/bin/env bash
set -euo pipefail

hermes_revision=7426c09beee73bdff94d916015bac71384f6bc92
pilot_image_tag="$hermes_revision-pilot6"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_name="${HERMES_APP:-the1000club-hermes}"
registry_image="registry.fly.io/$app_name:$pilot_image_tag"

for command_name in docker fly jq; do
    command -v "$command_name" >/dev/null || {
        echo "Missing required command: $command_name" >&2
        exit 1
    }
done

if fly machine list --app "$app_name" --json | jq --exit-status 'length > 0' >/dev/null; then
    fly ssh console \
        --app "$app_name" \
        --user hermes \
        --command '/opt/hermes/.venv/bin/python /opt/hermes-pilot/backup_to_tigris.py'
fi

"$script_dir/push-image.sh" >/dev/null

fly config validate --strict --app "$app_name" --config "$script_dir/fly.toml"
fly deploy \
    --app "$app_name" \
    --config "$script_dir/fly.toml" \
    --image "$registry_image" \
    --ha=false \
    --strategy immediate \
    --no-public-ips \
    --yes
fly scale count 1 --app "$app_name" --process-group app --yes
fly services list --app "$app_name"
fly ips list --app "$app_name"
