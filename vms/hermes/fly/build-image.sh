#!/usr/bin/env bash
set -euo pipefail

hermes_revision=7426c09beee73bdff94d916015bac71384f6bc92
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hermes_source="${HERMES_SOURCE_DIR:-$HOME/code/vicyap/the1000club/hermes-agent}"
bridge_source="${MAIL_BRIDGE_SOURCE_DIR:-$HOME/code/vicyap/the1000club/apps/mail-bridge}"
base_image="the1000club-hermes-base:$hermes_revision"
final_image="${HERMES_IMAGE:-the1000club-hermes:$hermes_revision}"

for command_name in docker git; do
    command -v "$command_name" >/dev/null || {
        echo "Missing required command: $command_name" >&2
        exit 1
    }
done

actual_revision="$(git -C "$hermes_source" rev-parse HEAD)"
if [[ "$actual_revision" != "$hermes_revision" ]]; then
    echo "Hermes source is $actual_revision; expected $hermes_revision" >&2
    exit 1
fi
if [[ -n "$(git -C "$hermes_source" status --porcelain)" ]]; then
    echo "Hermes source has local changes; refusing to build an unpinned image" >&2
    exit 1
fi
if [[ "$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$base_image" 2>/dev/null || true)" != "$hermes_revision" ]]; then
    docker build \
        --build-arg "HERMES_GIT_SHA=$hermes_revision" \
        --tag "$base_image" \
        "$hermes_source"
fi

build_context="$(mktemp -d)"
cleanup() {
    if [[ -n "${build_context:-}" && -d "$build_context" ]]; then
        rm -rf -- "$build_context"
    fi
}
trap cleanup EXIT

cp -a "$script_dir/." "$build_context/"
cp -a "$bridge_source/hermes-plugin" "$build_context/email-plugin"
docker build \
    --build-arg "HERMES_BASE_IMAGE=$base_image" \
    --build-arg "HERMES_GIT_SHA=$hermes_revision" \
    --tag "$final_image" \
    "$build_context"

docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$final_image" \
    | grep -qx "$hermes_revision"
printf '%s\n' "$final_image"
