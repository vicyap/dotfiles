#!/usr/bin/env bash
set -e

local_time=$(date '+%H:%M:%S %Z')
local_tz=$(date '+%Z')

if [[ "$local_tz" == "UTC" || "$local_tz" == "GMT" ]]; then
    printf '%s' "$local_time"
else
    utc_time=$(TZ=UTC date '+%H:%M:%S')
    printf '%s | %s UTC' "$local_time" "$utc_time"
fi
