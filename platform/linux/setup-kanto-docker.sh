#!/usr/bin/env bash
set -euo pipefail
[[ "$(hostname -s)" == kanto && "$EUID" == 0 ]]
install -d /etc/docker
candidate="$(mktemp)"
trap 'rm -f "$candidate"' EXIT
if [[ -f /etc/docker/daemon.json ]]; then
    cp /etc/docker/daemon.json "$candidate"
else
    echo '{}' >"$candidate"
fi
config="$(jq '. + {"log-driver":"local", "log-opts":{"max-size":"10m", "max-file":"3"}}
    | .builder.gc.enabled = true | .builder.gc.defaultKeepStorage = "20GB"' "$candidate")"
printf '%s\n' "$config" >"$candidate"
dockerd --validate --config-file "$candidate"
if ! cmp -s "$candidate" /etc/docker/daemon.json; then
    [[ -z "$(docker ps -q)" ]] || {
        echo 'Docker configuration requires an idle daemon.' >&2
        exit 1
    }
    install -m 0644 "$candidate" /etc/docker/daemon.json
    systemctl restart docker
fi
