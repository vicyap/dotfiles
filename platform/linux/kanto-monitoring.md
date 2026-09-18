# Kanto monitoring

Kanto sends its own resource metrics to a PostHog project.
`setup-kanto-monitoring.sh` installs Ubuntu's `prometheus-node-exporter` and
`prometheus-process-exporter` on `127.0.0.1:9100` and `127.0.0.1:9256`, a pinned
`otelcol-contrib` that scrapes both every 30 seconds and forwards to
`https://us.i.posthog.com/i/v1/metrics`, and `smartmontools` with a five-minute
`kanto-nvme-smart.timer` that writes both drives' SMART health to
`/var/lib/prometheus/node-exporter/nvme.prom` for the textfile collector.
Nothing listens beyond loopback and there is no dashboard on the host.

The write token is `POSTHOG_METRICS_TOKEN` in the host user's mode-0600
`~/.secrets`; the script copies it into root-owned, group-`otelcol-contrib`
`/etc/otelcol-contrib/config.yaml`. Host series carry `service.name =
machine-resources` and `host = kanto`; the guests send the same metric set
from their own provisioning, labelled `host` and `agent`, so a host query
filters on `host = 'kanto'` and a guest query on `agent`. Query series and
attributes through `posthog.metric_series` and `posthog.metrics`.

`setup-kanto.sh` invokes the three host setup scripts. For attended changes,
each can also run independently, for example with
`sudo bash platform/linux/setup-kanto-monitoring.sh`. Restarting the
exporters or the collector does not touch libvirt or the guests.

## Storage and memory

Kanto has a fully allocated 128 GiB `/swapfile`, persisted through `/etc/fstab`.
Zswap uses a 20% RAM ceiling and the kernel's existing compressor/pool defaults.
`/etc/tmpfiles.d/kanto-zswap.conf` enables it on boot. Zram and earlyoom are
disabled only after disk swap is active. Swappiness remains 60; overcommit
settings, guest RAM, guest swap, and slice CPU weights remain unchanged.

Docker keeps its storage on disk, uses the `local` log driver with 10 MiB × 3
files per container, and enables build-cache GC with a 20 GiB target. No volume
pruning is configured. Logging defaults apply to newly created containers.

## Measurement

node_exporter runs only the `cpu`, `meminfo`, `vmstat`, `pressure`, `loadavg`,
`diskstats`, `filesystem`, `netdev`, and `textfile` collectors, so the host
reports CPU time, memory and swap, reclaim and swap traffic, CPU/memory/I/O
pressure (PSI), load, disk I/O, filesystem capacity, and per-interface traffic
including each guest's `vnet*` tap. Docker's `veth`, `docker*`, and `br-*`
interfaces and its overlay mounts are excluded.

process_exporter groups processes by first match: `guest:<name>` for each
qemu process from its `-name guest=` flag, then `claude`, `codex`, `node`,
`docker`, and `other`. Each group reports CPU seconds, resident and virtual
memory, I/O bytes, open file descriptors, and process count, so a hot guest or
a host-side build is attributable without a series per PID.

The SMART textfile exposes `nvme_smart_healthy` and `nvme_smart_<field>` for
`critical_warning`, `temperature`, `available_spare`, `percentage_used`,
`media_errors`, `num_err_log_entries`, `unsafe_shutdowns`, `power_on_hours`,
`data_units_written`, and `data_units_read`, labelled by device, model, and
serial. SMART cannot predict every failure; the accepted RAID0 array holds both
the workloads and the swapfile.

Retention is PostHog's.

## Alerts

Nothing on the host evaluates alerts; `smartd` is disabled. The PostHog
project owns them, on a dashboard built from two SQL insights over
`posthog.metrics`, delivered to Slack through the project's Slack integration:

- One row per drive from the last hour of `nvme_smart_*`. Hourly alerts fire
  on `healthy` below 1, `critical_warning` above 0, and `media_errors` above
  0; daily alerts fire on `percentage_used` at or above 80 (warning) and 90
  (critical) and on `available_spare` at or below the drives' own threshold.
- A count of `node_load1` samples from `host = kanto` in the last 60 minutes;
  an hourly alert fires when it reaches 0, which is how a dead collector,
  exporter, or host shows up.
- A weekly dashboard subscription posts a snapshot of both insights.

PostHog re-posts a firing alert on every evaluation until it clears or is
snoozed in the UI, and does not announce clearing, so the evaluation interval
is the repeat cadence. Alerts only see what the collector sends: a drive that
has already taken the array down is reported by the no-data alert, not by the
SMART rows.

Read-only checks:

```sh
systemctl is-active prometheus-node-exporter prometheus-process-exporter otelcol-contrib kanto-nvme-smart.timer
curl -fsS http://127.0.0.1:9100/metrics | grep -E '^(node_pressure|nvme_smart_healthy)'
curl -fsS http://127.0.0.1:9256/metrics | grep '^namedprocess_namegroup_num_procs'
sudo journalctl -u otelcol-contrib --since today
```

Guest-local OOM remains possible with fixed guest RAM and no guest swap. Swap
cannot guarantee freedom from stalls or OOM. Do not induce host exhaustion to
test the pressure metrics.

References: [node_exporter collectors](https://github.com/prometheus/node_exporter),
[process-exporter configuration](https://github.com/ncabatoff/process-exporter),
[PostHog OpenTelemetry metrics](https://posthog.com/docs/metrics),
[Linux 6.8 zswap](https://docs.kernel.org/6.8/admin-guide/mm/zswap.html).
