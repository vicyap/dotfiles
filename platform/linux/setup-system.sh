#!/usr/bin/env bash
# rhinestone-only memory-pressure and NVMe-longevity configuration.
#
# Background: on 2026-06-17 rhinestone exhausted memory with no swap and no
# userspace OOM manager, thrashed reclaiming page cache, livelocked, and hard
# reset. The host also keeps high-churn temporary data in RAM and batches
# writeback to reduce NVMe wear.
#
# Idempotent and intentionally host-scoped: it refuses to run on any host other
# than rhinestone so these system-level changes never leak to another machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC_SRC="$SCRIPT_DIR/etc"
TARGET_HOST="rhinestone"
SWAPFILE="/swapfile"
SWAPFILE_SIZE="96G"
SWAPFILE_SIZE_BYTES=$((96 * 1024 * 1024 * 1024))
VAGRANT_NETWORK="vagrant-libvirt"
REQUIRED_DOMAINS=(engr-agent gtm-agent hermes)

require_host() {
    local host
    host="$(hostname -s 2>/dev/null || hostname)"
    if [[ "$host" != "$TARGET_HOST" ]]; then
        echo "Refusing to run: host is '$host', not '$TARGET_HOST'."
        echo "These memory-pressure changes are intentionally rhinestone-only."
        exit 0
    fi
}

require_linux_apt() {
    if [[ "$(uname -s)" != "Linux" ]] || ! command -v apt-get >/dev/null 2>&1; then
        echo "Skipped: not a Linux/apt system."
        exit 0
    fi
}

install_packages() {
    local want=(acl earlyoom systemd-zram-generator) missing=()
    local pkg
    for pkg in "${want[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if ((${#missing[@]} == 0)); then
        echo "ok packages present: ${want[*]}"
        return 0
    fi
    echo "+ installing: ${missing[*]}"
    # noninteractive: never block dotfiles sync on a debconf/needrestart prompt
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}

install_etc_file() {
    local rel="$1" dst="$2" mode="$3"
    local src="$ETC_SRC/$rel"
    if [[ ! -f "$src" ]]; then
        echo "! missing source: $src"
        return 1
    fi
    if sudo cmp -s "$src" "$dst" 2>/dev/null; then
        echo "ok $dst (unchanged)"
        return 0
    fi
    sudo install -D -m "$mode" "$src" "$dst"
    echo "+ wrote $dst"
}

validate_docker_config() {
    local config="$ETC_SRC/docker/daemon.json"
    if ! command -v jq >/dev/null 2>&1; then
        echo "! jq is required to validate $config"
        return 1
    fi
    if ! command -v dockerd >/dev/null 2>&1; then
        echo "! dockerd is required to validate $config"
        return 1
    fi
    jq empty "$config"
    dockerd --validate --config-file="$config"
}

validate_vm_inventory() {
    local domain details
    if ! command -v virsh >/dev/null 2>&1; then
        echo "! virsh is required to validate VM autostart"
        return 1
    fi
    if ! details="$(virsh -c qemu:///system net-info "$VAGRANT_NETWORK" 2>&1)"; then
        echo "! required libvirt network is absent: $VAGRANT_NETWORK"
        echo "$details"
        return 1
    fi
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        if ! details="$(virsh -c qemu:///system dominfo "$domain" 2>&1)"; then
            echo "! required libvirt domain is absent: $domain"
            echo "$details"
            return 1
        fi
    done
}

deploy_system_files() {
    install_etc_file "docker/daemon.json" "/etc/docker/daemon.json" 0644
    install_etc_file "systemd/zram-generator.conf" "/etc/systemd/zram-generator.conf" 0644
    install_etc_file "sysctl.d/99-rhinestone-memory.conf" "/etc/sysctl.d/99-rhinestone-memory.conf" 0644
    install_etc_file "sysctl.d/90-rhinestone-nvme-longevity.conf" "/etc/sysctl.d/90-rhinestone-nvme-longevity.conf" 0644
    install_etc_file "sysctl.d/90-rhinestone-network.conf" "/etc/sysctl.d/90-rhinestone-network.conf" 0644
    install_etc_file "sysctl.d/90-rhinestone-inotify.conf" "/etc/sysctl.d/90-rhinestone-inotify.conf" 0644
    install_etc_file "default/earlyoom" "/etc/default/earlyoom" 0644
    install_etc_file "systemd/system/rhinestone-memory-monitor.service" "/etc/systemd/system/rhinestone-memory-monitor.service" 0644
    install_etc_file "systemd/system/rhinestone-memory-monitor.timer" "/etc/systemd/system/rhinestone-memory-monitor.timer" 0644
    install_etc_file "systemd/system/periodic-sync.service" "/etc/systemd/system/periodic-sync.service" 0644
    install_etc_file "systemd/system/periodic-sync.timer" "/etc/systemd/system/periodic-sync.timer" 0644
    install_etc_file "systemd/system/fstrim.timer.d/10-rhinestone-weekly.conf" "/etc/systemd/system/fstrim.timer.d/10-rhinestone-weekly.conf" 0644
    install_etc_file "systemd/system/rhinestone-vagrant-tmpdirs.service" "/etc/systemd/system/rhinestone-vagrant-tmpdirs.service" 0644
    install_etc_file "systemd/system/libvirtd.service.d/10-rhinestone-vagrant-tmpdirs.conf" "/etc/systemd/system/libvirtd.service.d/10-rhinestone-vagrant-tmpdirs.conf" 0644
    install_etc_file "systemd/system/tailscaled.service.d/10-oom.conf" "/etc/systemd/system/tailscaled.service.d/10-oom.conf" 0644
    install_etc_file "systemd/system/ssh.service.d/10-oom.conf" "/etc/systemd/system/ssh.service.d/10-oom.conf" 0644
    install_etc_file "systemd/system/system.slice.d/10-access-memorymin.conf" "/etc/systemd/system/system.slice.d/10-access-memorymin.conf" 0644
    install_etc_file "systemd/system/user.slice.d/20-rhinestone-capacity.conf" "/etc/systemd/system/user.slice.d/20-rhinestone-capacity.conf" 0644
    install_etc_file "systemd/system/machine.slice.d/20-rhinestone-capacity.conf" "/etc/systemd/system/machine.slice.d/20-rhinestone-capacity.conf" 0644
    install_etc_file "systemd/system/docker.slice.d/20-rhinestone-capacity.conf" "/etc/systemd/system/docker.slice.d/20-rhinestone-capacity.conf" 0644
    install_etc_file "tmpfiles.d/tmp.conf" "/etc/tmpfiles.d/tmp.conf" 0644
    install_etc_file "tmpfiles.d/rhinestone-vagrant.conf" "/etc/tmpfiles.d/rhinestone-vagrant.conf" 0644
    install_etc_file "zsh/zshenv" "/etc/zsh/zshenv" 0644

    install_program "rhinestone-memory-snapshot"
    install_program "rhinestone-vagrant-tmpdirs"
}

install_program() {
    local name="$1"
    local src="$SCRIPT_DIR/usr/local/libexec/$name"
    local dst="/usr/local/libexec/$name"
    if sudo cmp -s "$src" "$dst" 2>/dev/null; then
        echo "ok $dst (unchanged)"
        return 0
    fi
    sudo install -D -m 0755 "$src" "$dst"
    echo "+ wrote $dst"
}

archive_legacy_longevity_sysctl() {
    local legacy="/etc/sysctl.d/99-nvme-longevity.conf"
    local archive="${legacy}.disabled"
    if [[ ! -e "$legacy" ]]; then
        echo "ok legacy NVMe sysctl disabled"
        return 0
    fi
    if sudo test -e "$archive"; then
        archive="${archive}.$(date -u +%Y%m%dT%H%M%SZ)"
    fi
    sudo mv "$legacy" "$archive"
    echo "+ archived $legacy as $archive"
}

archive_legacy_daily_fstrim_override() {
    local legacy="/etc/systemd/system/fstrim.timer.d/override.conf"
    local archive="${legacy}.disabled"
    if [[ ! -e "$legacy" ]]; then
        echo "ok vendor weekly fstrim schedule enabled"
        return 0
    fi
    if sudo test -e "$archive"; then
        archive="${archive}.$(date -u +%Y%m%dT%H%M%SZ)"
    fi
    sudo mv "$legacy" "$archive"
    echo "+ archived $legacy as $archive"
}

update_fstab() (
    local candidate
    candidate="$(mktemp)"
    trap 'rm -f "$candidate"' EXIT

    awk '
        function root_options(options, parts, count, result, position, option, saw_commit) {
            count = split(options, parts, ",")
            result = ""
            saw_commit = 0
            for (position = 1; position <= count; position++) {
                option = parts[position]
                if (option ~ /^(atime|relatime|strictatime|noatime)$/) {
                    continue
                }
                if (option ~ /^commit=/) {
                    if (!saw_commit) {
                        option = "commit=120"
                        saw_commit = 1
                    } else {
                        continue
                    }
                }
                result = result (result == "" ? "" : ",") option
            }
            if (!saw_commit) {
                result = result (result == "" ? "" : ",") "commit=120"
            }
            return result ",noatime"
        }

        /^[[:space:]]*#/ || NF < 4 {
            print
            next
        }

        $2 == "/" {
            if (!saw_root) {
                printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, root_options($4), $5, $6
                saw_root = 1
            }
            next
        }

        $2 == "/tmp" {
            if (!saw_tmp) {
                print "tmpfs\t/tmp\ttmpfs\tdefaults,mode=1777,size=36G\t0\t0"
                saw_tmp = 1
            }
            next
        }

        $2 == "/var/tmp" {
            if (!saw_var_tmp) {
                print "tmpfs\t/var/tmp\ttmpfs\tdefaults,mode=1777,size=4G\t0\t0"
                saw_var_tmp = 1
            }
            next
        }

        $2 == "/var/lib/docker/tmp" {
            if (!saw_docker_tmp) {
                print "tmpfs\t/var/lib/docker/tmp\ttmpfs\tdefaults,size=16G,mode=1777\t0\t0"
                saw_docker_tmp = 1
            }
            next
        }

        $1 == "/swapfile" && $2 == "none" && $3 == "swap" {
            if (!saw_swapfile) {
                print "/swapfile\tnone\tswap\tsw,pri=-1\t0\t0"
                saw_swapfile = 1
            }
            next
        }

        { print }

        END {
            if (!saw_root) {
                exit 42
            }
            if (!saw_tmp) {
                print "tmpfs\t/tmp\ttmpfs\tdefaults,mode=1777,size=36G\t0\t0"
            }
            if (!saw_var_tmp) {
                print "tmpfs\t/var/tmp\ttmpfs\tdefaults,mode=1777,size=4G\t0\t0"
            }
            if (!saw_docker_tmp) {
                print "tmpfs\t/var/lib/docker/tmp\ttmpfs\tdefaults,size=16G,mode=1777\t0\t0"
            }
            if (!saw_swapfile) {
                print "/swapfile\tnone\tswap\tsw,pri=-1\t0\t0"
            }
        }
    ' /etc/fstab >"$candidate"

    sudo findmnt --verify --tab-file "$candidate" >/dev/null
    if sudo cmp -s "$candidate" /etc/fstab; then
        echo "ok /etc/fstab targeted entries unchanged"
        return 0
    fi
    if ! sudo test -e /etc/fstab.rhinestone-before-managed; then
        sudo cp --archive /etc/fstab /etc/fstab.rhinestone-before-managed
        echo "+ backed up /etc/fstab"
    fi
    sudo install -m 0644 "$candidate" /etc/fstab
    echo "+ updated targeted /etc/fstab entries"
)

setup_swapfile() {
    local actual_size active_priority swap_type
    if [[ -e "$SWAPFILE" ]]; then
        actual_size="$(sudo stat -c %s "$SWAPFILE")"
        if ((actual_size != SWAPFILE_SIZE_BYTES)); then
            echo "! $SWAPFILE size mismatch: got $actual_size bytes, want $SWAPFILE_SIZE_BYTES bytes"
            echo "! resize it with the capacity-first pre-reboot procedure before rerunning"
            return 1
        fi
    else
        echo "+ allocating $SWAPFILE ($SWAPFILE_SIZE)"
        sudo fallocate -l "$SWAPFILE_SIZE" "$SWAPFILE"
    fi

    sudo chmod 600 "$SWAPFILE"
    if swapon --show=NAME --noheadings 2>/dev/null | awk -v target="$SWAPFILE" '$1 == target { found = 1 } END { exit !found }'; then
        active_priority="$(swapon --show=NAME,PRIO --noheadings | awk -v target="$SWAPFILE" '$1 == target { print $2; exit }')"
        if [[ "$active_priority" != "-1" ]]; then
            echo "! $SWAPFILE priority mismatch: got $active_priority, want -1"
            return 1
        fi
        echo "ok $SWAPFILE active at $SWAPFILE_SIZE with priority -1"
    else
        swap_type="$(sudo blkid -p -s TYPE -o value "$SWAPFILE" 2>/dev/null || true)"
        if [[ "$swap_type" != "swap" ]]; then
            sudo mkswap "$SWAPFILE" >/dev/null
        fi
        sudo swapon --priority -1 "$SWAPFILE"
        echo "+ $SWAPFILE enabled ($SWAPFILE_SIZE, priority -1)"
    fi
}

configure_vm_autostart() {
    local domain
    virsh -c qemu:///system net-autostart "$VAGRANT_NETWORK" >/dev/null
    echo "ok libvirt network autostart enabled: $VAGRANT_NETWORK"
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        virsh -c qemu:///system autostart "$domain" >/dev/null
        echo "ok libvirt domain autostart enabled: $domain"
    done
}

apply_soft_resource_controls() {
    local entry unit memory_high
    for entry in \
        "user.slice:40G" \
        "machine.slice:32G" \
        "docker.slice:12G"; do
        unit="${entry%%:*}"
        memory_high="${entry##*:}"
        sudo systemctl start "$unit"
        sudo systemctl set-property --runtime "$unit" "MemoryHigh=$memory_high" CPUWeight=75
        echo "ok $unit MemoryHigh=$memory_high CPUWeight=75 (live)"
    done
}

enable_services() {
    sudo systemctl daemon-reload

    # zram: the generator builds units from zram-generator.conf; (re)start the
    # setup service and activate the swap device. `start` leaves an already
    # active zram device untouched; the new size applies after reboot.
    sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true
    sudo systemctl start dev-zram0.swap 2>/dev/null || true

    # Apply the joint RAM/swap policy now, while the host is healthy.
    sudo systemctl enable earlyoom.service >/dev/null
    sudo systemctl restart earlyoom.service

    # Record structured memory, swap, zram, and pressure metrics in journald.
    sudo systemctl enable --now rhinestone-memory-monitor.timer >/dev/null
    sudo systemctl start rhinestone-memory-monitor.service

    sudo systemctl enable --now periodic-sync.timer >/dev/null
    sudo systemctl enable rhinestone-vagrant-tmpdirs.service >/dev/null
    sudo systemctl start rhinestone-vagrant-tmpdirs.service
    sudo systemctl enable fstrim.timer >/dev/null
    sudo systemctl restart fstrim.timer
}

apply_mount_configuration() {
    sudo mount -o remount,noatime,commit=120 /

    local target
    for target in /tmp /var/tmp /var/lib/docker/tmp; do
        if sudo mountpoint -q "$target"; then
            sudo mount -o remount "$target"
        else
            sudo mount "$target"
        fi
    done

    sudo systemd-tmpfiles --create /etc/tmpfiles.d/tmp.conf
}

protect_tailscaled() {
    # The tailscaled.service.d drop-in applies on the next restart; restarting
    # tailscaled here would drop live tailnet SSH sessions, so also set the
    # running daemon's score directly.
    local pid
    pid="$(pgrep -xo tailscaled || true)"
    if [[ -n "$pid" ]]; then
        echo -1000 | sudo tee "/proc/$pid/oom_score_adj" >/dev/null
        echo "ok tailscaled oom_score_adj=-1000 (live, pid $pid)"
    else
        echo "! tailscaled not running; drop-in applies on next start"
    fi
}

apply_memory_min() {
    # The MemoryMin drop-ins apply on service restart; write the cgroup files
    # directly so the protection holds now without restarting sshd/tailscaled.
    local cg entry
    for entry in \
        "/sys/fs/cgroup/system.slice:268435456" \
        "/sys/fs/cgroup/system.slice/ssh.service:134217728" \
        "/sys/fs/cgroup/system.slice/tailscaled.service:134217728"; do
        cg="${entry%%:*}"
        if [[ -f "$cg/memory.min" ]]; then
            echo "${entry##*:}" | sudo tee "$cg/memory.min" >/dev/null
            echo "ok memory.min=${entry##*:} ($cg)"
        else
            echo "! no cgroup at $cg; drop-in applies on next start"
        fi
    done
}

apply_sysctl() {
    sudo sysctl --system >/dev/null
    echo "ok sysctl applied (swappiness=$(</proc/sys/vm/swappiness), page-cluster=$(</proc/sys/vm/page-cluster), vfs_cache_pressure=$(</proc/sys/vm/vfs_cache_pressure))"
}

summary() {
    echo
    echo "== memory safety status =="
    swapon --show
    echo
    zramctl 2>/dev/null || true
    echo
    printf "earlyoom: %s\n" "$(systemctl is-active earlyoom.service)"
    printf "memory monitor: %s\n" "$(systemctl is-active rhinestone-memory-monitor.timer)"
    printf "periodic sync: %s\n" "$(systemctl is-active periodic-sync.timer)"
    printf "weekly trim: %s\n" "$(systemctl is-active fstrim.timer)"
    systemctl show user.slice machine.slice docker.slice -p Id -p MemoryHigh -p MemoryMax -p CPUWeight
    virsh -c qemu:///system net-info "$VAGRANT_NETWORK" | awk '/^(Name|Autostart):/'
    local domain
    for domain in "${REQUIRED_DOMAINS[@]}"; do
        virsh -c qemu:///system dominfo "$domain" | awk '/^(Name|Autostart):/'
    done
    local mount_target
    for mount_target in / /tmp /var/tmp /var/lib/docker/tmp; do
        findmnt -T "$mount_target" -no TARGET,FSTYPE,SIZE,OPTIONS
    done
    local ts_pid
    ts_pid="$(pgrep -xo tailscaled || true)"
    if [[ -n "$ts_pid" ]]; then
        printf "tailscaled oom_score_adj: %s\n" "$(cat "/proc/$ts_pid/oom_score_adj")"
    fi
}

main() {
    require_host
    require_linux_apt
    validate_docker_config
    validate_vm_inventory
    install_packages
    deploy_system_files
    archive_legacy_longevity_sysctl
    archive_legacy_daily_fstrim_override
    setup_swapfile
    update_fstab
    apply_sysctl
    apply_mount_configuration
    enable_services
    apply_soft_resource_controls
    configure_vm_autostart
    protect_tailscaled
    apply_memory_min
    summary
}

main "$@"
