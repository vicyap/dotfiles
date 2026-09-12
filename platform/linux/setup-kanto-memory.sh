#!/usr/bin/env bash
set -euo pipefail

[[ "$(hostname -s)" == kanto && "$EUID" == 0 ]] || {
    echo 'Run as root on kanto.' >&2
    exit 1
}
swapfile=/swapfile
swap_bytes=$((128 * 1024 * 1024 * 1024))
if [[ ! -e "$swapfile" ]]; then
    available="$(df --output=avail -B1 / | tail -1)"
    ((available > swap_bytes + 20 * 1024 * 1024 * 1024)) || {
        echo 'Insufficient disk space for swap plus 20 GiB headroom.' >&2
        exit 1
    }
    install -m 0600 /dev/null "$swapfile"
    dd if=/dev/zero of="$swapfile" bs=16M count=8192 conv=fsync status=progress
    mkswap "$swapfile"
fi
[[ ! -L "$swapfile" && "$(stat -c %s "$swapfile")" == "$swap_bytes" ]]
(($(stat -c %b "$swapfile") * 512 >= swap_bytes))
[[ "$(blkid -p -s TYPE -o value "$swapfile")" == swap ]]
chmod 0600 "$swapfile"
if ! swapon --show=NAME --noheadings | grep -Fxq "$swapfile"; then
    swapon "$swapfile"
fi
swapon --show=NAME --noheadings | grep -Fxq "$swapfile"
if ! awk '$1 == "/swapfile" && $3 == "swap" { found=1 } END { exit !found }' /etc/fstab; then
    printf '/swapfile none swap sw 0 0\n' >>/etc/fstab
fi
systemctl daemon-reload

# Backing swap is active before compressed-only swap and earlyoom are retired.
echo 20 >/sys/module/zswap/parameters/max_pool_percent
echo Y >/sys/module/zswap/parameters/enabled
cat >/etc/tmpfiles.d/kanto-zswap.conf <<'EOF'
w /sys/module/zswap/parameters/max_pool_percent - - - - 20
w /sys/module/zswap/parameters/enabled - - - - Y
EOF
if swapon --show=NAME --noheadings | grep -Fxq /dev/zram0; then
    swapoff /dev/zram0
fi
printf '# Kanto uses zswap backed by /swapfile.\n' >/etc/systemd/zram-generator.conf
systemctl stop systemd-zram-setup@zram0.service
systemctl daemon-reload
systemctl disable --now earlyoom.service
swapon --show
