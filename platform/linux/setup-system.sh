#!/usr/bin/env bash
# rhinestone-only memory-pressure hardening: zram + disk swapfile + earlyoom.
#
# Background: on 2026-06-17 rhinestone exhausted memory with no swap and no
# userspace OOM manager, thrashed reclaiming page cache, livelocked, and hard
# reset. This script makes memory pressure degrade gracefully instead.
#
# Idempotent and intentionally host-scoped: it refuses to run on any host other
# than rhinestone so these system-level changes never leak to another machine.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC_SRC="$SCRIPT_DIR/etc"
TARGET_HOST="rhinestone"
SWAPFILE="/swapfile"
SWAPFILE_SIZE="64G"

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
    local want=(earlyoom systemd-zram-generator) missing=()
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

deploy_etc() {
    install_etc_file "systemd/zram-generator.conf" "/etc/systemd/zram-generator.conf" 0644
    install_etc_file "sysctl.d/99-rhinestone-memory.conf" "/etc/sysctl.d/99-rhinestone-memory.conf" 0644
    install_etc_file "default/earlyoom" "/etc/default/earlyoom" 0644
}

ensure_fstab() {
    if ! grep -qE "^[[:space:]]*${SWAPFILE}[[:space:]]" /etc/fstab; then
        echo "${SWAPFILE} none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
        echo "+ added ${SWAPFILE} to /etc/fstab"
    fi
}

setup_swapfile() {
    if swapon --show=NAME --noheadings 2>/dev/null | grep -qx "$SWAPFILE"; then
        echo "ok $SWAPFILE already active"
    else
        if [[ ! -f "$SWAPFILE" ]]; then
            echo "+ allocating $SWAPFILE ($SWAPFILE_SIZE)"
            sudo fallocate -l "$SWAPFILE_SIZE" "$SWAPFILE"
        fi
        sudo chmod 600 "$SWAPFILE"
        sudo mkswap "$SWAPFILE" >/dev/null
        sudo swapon "$SWAPFILE"
        echo "+ $SWAPFILE enabled ($SWAPFILE_SIZE)"
    fi
    ensure_fstab
}

enable_services() {
    sudo systemctl daemon-reload

    # zram: the generator builds units from zram-generator.conf; (re)start the
    # setup service and activate the swap device.
    sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true
    sudo systemctl start dev-zram0.swap 2>/dev/null || true

    # earlyoom: enable at boot and (re)start to pick up /etc/default/earlyoom.
    sudo systemctl enable earlyoom.service >/dev/null 2>&1 || true
    sudo systemctl restart earlyoom.service
}

apply_sysctl() {
    sudo sysctl --system >/dev/null
    echo "ok sysctl applied (swappiness=$(cat /proc/sys/vm/swappiness), page-cluster=$(cat /proc/sys/vm/page-cluster))"
}

summary() {
    echo
    echo "== memory safety status =="
    swapon --show
    echo
    zramctl 2>/dev/null || true
    echo
    printf "earlyoom: %s\n" "$(systemctl is-active earlyoom.service)"
}

main() {
    require_host
    require_linux_apt
    install_packages
    deploy_etc
    setup_swapfile
    apply_sysctl
    enable_services
    summary
}

main "$@"
