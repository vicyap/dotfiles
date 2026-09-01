#!/usr/bin/env bash
set -euo pipefail

fly_org=the1000club
primary_app=the1000club-hermes
fallback_app=the1000club-fit-hermes
bucket_name=the1000club-hermes-backups
app_name="${HERMES_APP:-$primary_app}"

for command_name in fly jq; do
    command -v "$command_name" >/dev/null || {
        echo "Missing required command: $command_name" >&2
        exit 1
    }
done

if ! fly orgs list --json \
    | jq --arg org "$fly_org" --exit-status 'has($org)' >/dev/null; then
    fly orgs create "$fly_org"
fi

if ! fly status --app "$app_name" >/dev/null 2>&1; then
    app_error="$(mktemp)"
    if ! fly apps create "$app_name" --org "$fly_org" --yes 2>"$app_error"; then
        if [[ "$app_name" == "$primary_app" ]] && rg -qi 'already (exists|been taken)|name.*taken' "$app_error"; then
            app_name="$fallback_app"
            fly apps create "$app_name" --org "$fly_org" --yes
        else
            cat "$app_error" >&2
            rm -f "$app_error"
            exit 1
        fi
    fi
    rm -f "$app_error"
fi

if ! fly storage status "$bucket_name" --app "$app_name" >/dev/null 2>&1; then
    fly storage create \
        --app "$app_name" \
        --name "$bucket_name" \
        --org "$fly_org" \
        --yes >/dev/null
fi
fly storage update "$bucket_name" --app "$app_name" --org "$fly_org" --private --yes
printf '%s\n' 'AWS_ENDPOINT_URL_S3=https://t3.storage.dev' \
    | fly secrets import --app "$app_name" --stage

if ! fly volumes list --app "$app_name" --json \
    | jq --exit-status 'any(.[]; .name == "hermes_data")' >/dev/null; then
    fly volumes create hermes_data \
        --app "$app_name" \
        --region sjc \
        --size 5 \
        --snapshot-retention 30 \
        --scheduled-snapshots \
        --yes
fi

printf 'HERMES_APP=%s\n' "$app_name"
