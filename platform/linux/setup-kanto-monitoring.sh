#!/usr/bin/env bash
set -euo pipefail

[[ "$(hostname -s)" == kanto && "$EUID" == 0 ]] || {
    echo 'Run as root on kanto.' >&2
    exit 1
}
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d /etc/netdata /etc/netdata/go.d /etc/netdata/health.d
install -m 0644 "$script_dir/etc/netdata/kanto.conf" /etc/netdata/netdata.conf
install -m 0644 "$script_dir/etc/netdata/ebpf.d.conf" /etc/netdata/ebpf.d.conf
install -m 0644 "$script_dir/etc/netdata/health.d/memory-pressure.conf" /etc/netdata/health.d/memory-pressure.conf
touch /etc/netdata/.opt-out-from-anonymous-statistics
if ! dpkg-query -W -f='${Status}' netdata-repo 2>/dev/null | grep -q 'install ok installed'; then
    installer="$(mktemp)"
    curl -fsSL https://get.netdata.cloud/kickstart.sh -o "$installer"
    sh "$installer" --repositories-only --stable-channel --non-interactive --disable-telemetry
    rm -f "$installer"
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -o Dpkg::Options::=--force-confold install -y netdata netdata-plugin-ebpf \
    netdata-plugin-debugfs netdata-plugin-go nvme-cli
printf 'jobs:\n  - name: nvme\n    update_every: 10\n' >/etc/netdata/go.d/nvme.conf

secrets_file="$(getent passwd "${SUDO_USER:?Run through sudo}")"
secrets_file="$(cut -d: -f6 <<<"$secrets_file")/.secrets"
if ! test -f "$secrets_file" || ! grep -q '^NETDATA_STREAM_API_KEY=' "$secrets_file"; then
    (
        umask 077
        printf '\nNETDATA_STREAM_API_KEY=%s\n' "$(cat /proc/sys/kernel/random/uuid)" >>"$secrets_file"
    )
    chown "$SUDO_USER:" "$secrets_file"
fi
api_key="$(sed -n 's/^NETDATA_STREAM_API_KEY=//p' "$secrets_file")"
[[ "$api_key" =~ ^[0-9a-f-]{36}$ ]]
(
    umask 077
    cat >/etc/netdata/stream.conf <<EOF
[$api_key]
    type = api
    enabled = yes
    allow from = 192.168.121.*
    db = dbengine
    health enabled = yes
EOF
)
chown root:netdata /etc/netdata/stream.conf
chmod 0640 /etc/netdata/stream.conf

install -m 0644 "$script_dir/etc/kanto-firewall.nft" /etc/kanto-firewall.nft
nft --check -f /etc/kanto-firewall.nft
systemctl reload kanto-firewall.service
systemctl enable netdata
systemctl restart netdata
