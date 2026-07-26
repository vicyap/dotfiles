#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)) || [[ ! "$1" =~ ^[[:xdigit:]]{31}$ ]]; then
    echo "Usage: $0 <31-character 9p mount tag>" >&2
    exit 2
fi

mount_tag="$1"

modprobe 9p
modprobe 9pnet_virtio

device_present=false
for mount_tag_path in /sys/bus/virtio/devices/*/mount_tag; do
    [[ -r "$mount_tag_path" ]] || continue
    device_mount_tag=""
    IFS= read -r -d '' device_mount_tag <"$mount_tag_path" || true
    if [[ "$device_mount_tag" == "$mount_tag" ]]; then
        device_present=true
        break
    fi
done

# Other Vagrant providers retain their existing /tmp.
if [[ "$device_present" != true ]]; then
    exit 0
fi

install -d -m 1777 /tmp
if ! findmnt -rn -T /tmp -o SOURCE,FSTYPE | grep -Fqx "$mount_tag 9p"; then
    mount -t 9p -o trans=virtio,version=9p2000.L "$mount_tag" /tmp
fi
chmod 1777 /tmp

install -d -m 0755 /etc/tmpfiles.d
printf '%s\n' 'D /tmp 1777 root root 7d' >/etc/tmpfiles.d/tmp.conf
chmod 0644 /etc/tmpfiles.d/tmp.conf

candidate="$(mktemp)"
trap 'rm -f "$candidate"' EXIT
awk -v mount_tag="$mount_tag" '
    /^[[:space:]]*#/ || NF < 4 {
        print
        next
    }
    $2 == "/tmp" {
        if (!saw_tmp) {
            printf "%s\t/tmp\t9p\ttrans=virtio,version=9p2000.L,nofail\t0\t0\n", mount_tag
            saw_tmp = 1
        }
        next
    }
    { print }
    END {
        if (!saw_tmp) {
            printf "%s\t/tmp\t9p\ttrans=virtio,version=9p2000.L,nofail\t0\t0\n", mount_tag
        }
    }
' /etc/fstab >"$candidate"
findmnt --verify --tab-file "$candidate" >/dev/null
install -m 0644 "$candidate" /etc/fstab

systemd-tmpfiles --create /etc/tmpfiles.d/tmp.conf
