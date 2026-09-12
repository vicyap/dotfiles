# Kanto monitoring

Kanto retains its own and the three coworker guests' Netdata history. The native
agents use Netdata's stable APT channel. Open
`https://kanto.llama-bull.ts.net` from a device connected to the tailnet.
Tailscale Serve proxies HTTPS to Netdata on `127.0.0.1:19999`; its background
configuration persists across restarts. `setup-kanto.sh` configures the proxy
when Tailscale is signed in. Funnel is not enabled.

The four nodes' metrics, history, and alerts are available without a Netdata
Cloud account or SSH tunnel. Guest streaming uses
`192.168.121.1:19999` on the libvirt network; dashboard requests from guests are
denied. No public interface listens on port 19999.

`setup-kanto.sh` invokes the three host setup scripts. For attended changes,
each can also run independently, for example with
`sudo bash platform/linux/setup-kanto-monitoring.sh`. Netdata restarts do not restart coworkers.
Temi's `apps/agent-runtime/deploy/monitoring.sh` owns guest monitoring and Docker
configuration, with its provisioning contract in `docs/agent-provisioning.md`.

The streaming key is `NETDATA_STREAM_API_KEY` in the host user's mode-0600
`~/.secrets`. The parent installs `/etc/netdata/stream.conf` as root:netdata 0640.
Guest inputs are mode-0600 `netdata-stream.secrets` beside each deployment
Vagrantfile, or in `AGENT_CREDENTIALS_DIR`; they contain the `[stream]` section,
`enabled = yes`, `destination = 192.168.121.1:19999`, and the matching `api key`.
They never enter Git or the coworker session environment.

## Storage and memory

| Tier | Resolution | Retention target | Shared disk budget |
| --- | --- | --- | --- |
| 0 | 1 second | 24 hours | 4 GiB |
| 1 | 1 minute | 7 days | 4 GiB |
| 2 | 1 hour | 30 days | 2 GiB |

The budgets cover all four nodes. Netdata deletes data at whichever limit is
reached first; budgets are soft limits. Guest buffers are in RAM, with durable
history on kanto under `/var/cache/netdata`.

Kanto has a fully allocated 128 GiB `/swapfile`, persisted through `/etc/fstab`.
Zswap uses a 20% RAM ceiling and the kernel's existing compressor/pool defaults.
`/etc/tmpfiles.d/kanto-zswap.conf` enables it on boot. Zram and earlyoom are
disabled only after disk swap is active. Swappiness remains 60; overcommit
settings, guest RAM, guest swap, and slice CPU weights remain unchanged.

Docker keeps its storage on disk, uses the `local` log driver with 10 MiB × 3
files per container, and enables build-cache GC with a 20 GiB target. No volume
pruning is configured. Logging defaults apply to newly created containers.

## Measurement

The parent collects NVMe health for both physical drives, zswap compression and
writeback, CPU/memory/I/O pressure, reclaim, swap traffic, filesystem capacity,
disk I/O, and VM/container resource metrics. All four nodes enable eBPF disk,
filesystem, swap, and OOM collectors. NVMe health is sampled every ten seconds.

Stock capacity and disk-health alerts remain enabled. Sustained full memory
pressure above 1% over a minute raises a dashboard warning. The parent's alert
handler is `/bin/true`: no email, chat, or webhook delivery. Guest alerts are
evaluated on the parent.

Use these read-only checks after 24 hours, seven days, and 30 days of collection:

```sh
curl -fsS http://127.0.0.1:19999/api/v1/info | jq .mirrored_hosts
curl -fsS http://127.0.0.1:19999/api/v3/info | jq '.agents[0].db_size'
curl -fsS 'http://127.0.0.1:19999/api/v1/alarms?all' | jq '.alarms'
sudo journalctl --namespace=netdata --since today
```

Compare pressure duration with swap-in/out, zswap compression and writeback,
disk-latency histograms, NVMe writes, and actual per-tier retention. Idle swap
and OOM charts can legitimately stay at zero. Do not induce host exhaustion to
test them. The first 30 days establish retention; a newly configured target is
not evidence that that much history exists.

Manual rollout verification on 2026-09-12 confirmed four nodes, all four eBPF
modules on each, both NVMe devices, private listeners, and identical historical
CPU samples before and after a parent Netdata restart. Coworker supervisor PIDs
were unchanged. A host reboot was not performed.

Guest-local OOM remains possible with fixed guest RAM and no guest swap. Swap
cannot guarantee freedom from stalls or OOM. SMART cannot predict every failure;
the accepted RAID0 array holds both the workloads and their local history.

References: [Netdata retention](https://learn.netdata.cloud/docs/netdata-agent/configuration/database),
[anonymous dashboard access](https://learn.netdata.cloud/docs/security-and-privacy-design/access-control-and-feature-availability),
[Linux 6.8 zswap](https://docs.kernel.org/6.8/admin-guide/mm/zswap.html).
