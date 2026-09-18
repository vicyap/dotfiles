#!/usr/bin/env bash
# Host resource telemetry to PostHog: node and process exporters scraped by an OpenTelemetry
# collector, plus NVMe SMART health through node_exporter's textfile collector.
set -euo pipefail

[[ "$(hostname -s)" == kanto && "$EUID" == 0 ]] || {
    echo 'Run as root on kanto.' >&2
    exit 1
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
otelcol_version=0.161.0

secrets_file="$(getent passwd "${SUDO_USER:?Run through sudo}")"
secrets_file="$(cut -d: -f6 <<<"$secrets_file")/.secrets"
token="$(sed -n 's/^POSTHOG_METRICS_TOKEN=//p' "$secrets_file" 2>/dev/null || true)"
[[ "$token" =~ ^phc_[A-Za-z0-9]+$ ]] || {
    echo "POSTHOG_METRICS_TOKEN (the temi-engr project write token) is missing from $secrets_file." >&2
    exit 1
}

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends prometheus-node-exporter prometheus-process-exporter smartmontools
if [[ "$(dpkg-query -W -f='${Version}' otelcol-contrib 2>/dev/null)" != "$otelcol_version" ]]; then
    package="$(mktemp --suffix=.deb)"
    curl -fsSL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${otelcol_version}/otelcol-contrib_${otelcol_version}_linux_amd64.deb" \
        -o "$package"
    dpkg -i --force-confold "$package"
    rm -f "$package"
fi

# PSI (the pressure collector) is the contention signal. vnet and virbr interfaces stay: they are
# the per-guest network signal. The filters keep Docker's interfaces and mounts from multiplying series.
cat >/etc/default/prometheus-node-exporter <<'CONFIG'
ARGS="--web.listen-address=127.0.0.1:9100 --collector.disable-defaults --collector.cpu --collector.meminfo --collector.vmstat --collector.pressure --collector.loadavg --collector.diskstats --collector.filesystem --collector.netdev --collector.textfile --collector.textfile.directory=/var/lib/prometheus/node-exporter --collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys|var/lib/docker)($|/) --collector.netdev.device-exclude=^(lo|veth|docker|br-)"
CONFIG
# Named groups, first match wins. Each guest's qemu process is its own group so a hot guest is
# attributable from the host side.
cat >/etc/prometheus-process-exporter.yml <<'CONFIG'
process_names:
  - name: "guest:{{.Matches.Guest}}"
    exe: [qemu-system-x86_64]
    cmdline: ["-name guest=(?P<Guest>[^,]+)"]
  - name: claude
    exe: [claude]
  - name: codex
    exe: [codex]
  - name: node
    exe: [node, npm, pnpm]
  - name: docker
    exe: [dockerd, containerd, containerd-shim-runc-v2]
  - name: other
    cmdline: [".+"]
CONFIG
cat >/etc/default/prometheus-process-exporter <<'CONFIG'
ARGS="-web.listen-address=127.0.0.1:9256 -config.path=/etc/prometheus-process-exporter.yml -threads=false -gather-smaps=false"
CONFIG

install -d -m 0755 /var/lib/prometheus/node-exporter
install -D -m 0755 "$script_dir/usr/local/libexec/kanto-nvme-smart" /usr/local/libexec/kanto-nvme-smart
install -m 0644 "$script_dir/etc/systemd/system/kanto-nvme-smart.service" \
    "$script_dir/etc/systemd/system/kanto-nvme-smart.timer" /etc/systemd/system/
systemctl daemon-reload

# Guests label their series with agent=<name>; the host is only host=kanto.
config="$(mktemp)"
trap 'rm -f "$config"' EXIT
cat >"$config" <<CONFIG
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: node
          scrape_interval: 30s
          static_configs:
            - targets: ['127.0.0.1:9100']
        - job_name: process
          scrape_interval: 30s
          static_configs:
            - targets: ['127.0.0.1:9256']
processors:
  resource:
    attributes:
      - {key: service.name, value: machine-resources, action: upsert}
      - {key: host, value: kanto, action: upsert}
  batch: {}
exporters:
  otlphttp:
    metrics_endpoint: https://us.i.posthog.com/i/v1/metrics
    headers:
      Authorization: Bearer $token
service:
  telemetry:
    metrics:
      level: none
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [resource, batch]
      exporters: [otlphttp]
CONFIG
install -m 0640 -o root -g otelcol-contrib "$config" /etc/otelcol-contrib/config.yaml
otelcol-contrib validate --config=/etc/otelcol-contrib/config.yaml
systemctl enable prometheus-node-exporter prometheus-process-exporter otelcol-contrib kanto-nvme-smart.timer
systemctl restart prometheus-node-exporter prometheus-process-exporter otelcol-contrib
systemctl start kanto-nvme-smart.service kanto-nvme-smart.timer
