#!/usr/bin/env bash
set -euo pipefail

hermes_revision=7426c09beee73bdff94d916015bac71384f6bc92
pilot_image_tag="$hermes_revision-pilot6"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_name="${HERMES_APP:-the1000club-hermes}"
local_image="the1000club-hermes:$hermes_revision"
registry_image="registry.fly.io/$app_name:$pilot_image_tag"

HERMES_IMAGE="$local_image" "$script_dir/build-image.sh" >/dev/null
fly auth docker
docker tag "$local_image" "$registry_image"
docker push "$registry_image"
printf '%s\n' "$registry_image"
