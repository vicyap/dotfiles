#!/usr/bin/env bash
set -euo pipefail

export HOME=/opt/data
export HERMES_HOME=/opt/data
export PATH="/command:$PATH"

/opt/hermes/docker/stage2-hook.sh
/bin/sh /etc/cont-init.d/014-hermes-pilot

browser_environment=/run/s6/container_environment/AGENT_BROWSER_EXECUTABLE_PATH
if [[ -z "${AGENT_BROWSER_EXECUTABLE_PATH:-}" && -s "$browser_environment" ]]; then
    AGENT_BROWSER_EXECUTABLE_PATH="$(<"$browser_environment")"
    export AGENT_BROWSER_EXECUTABLE_PATH
fi

if (($#)); then
    exec /command/s6-setuidgid hermes "$@"
fi

gateway_pid=
jobs_pid=
shutdown_requested=false

terminate_children() {
    [[ -z "$gateway_pid" ]] || kill -TERM "$gateway_pid" 2>/dev/null || true
    [[ -z "$jobs_pid" ]] || kill -TERM "$jobs_pid" 2>/dev/null || true
}

# shellcheck disable=SC2329
request_shutdown() {
    shutdown_requested=true
    terminate_children
}

trap request_shutdown TERM INT HUP

/command/s6-setuidgid hermes \
    /opt/hermes/.venv/bin/python -m hermes_cli.main gateway run &
gateway_pid=$!
/command/s6-setuidgid hermes /opt/hermes-pilot/pilot-jobs.sh &
jobs_pid=$!

set +e
wait -n "$gateway_pid" "$jobs_pid"
child_status=$?
set -e

if [[ "$shutdown_requested" == false ]]; then
    echo "Hermes gateway or pilot jobs exited; restarting the Machine" >&2
fi
terminate_children
set +e
wait "$gateway_pid"
wait "$jobs_pid"
set -e

[[ "$shutdown_requested" == true ]] && exit 0
((child_status == 0)) && exit 1
exit "$child_status"
