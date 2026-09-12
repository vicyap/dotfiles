#!/usr/bin/env bash
# Kanto's libvirt host: fixed guest RAM and relative CPU priority for host work.
set -euo pipefail

[[ "$(uname -s)" == Linux && "$(hostname -s)" == kanto ]] || {
    echo "Skipped: this configuration applies only to kanto."
    exit 0
}
# shellcheck disable=SC1091
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || {
    echo "Kanto provisioning requires Ubuntu 24.04." >&2
    exit 1
}
[[ -e /dev/kvm ]] || {
    echo "KVM is unavailable." >&2
    exit 1
}

sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl git jq qemu-system-x86 libvirt-daemon-system libvirt-clients \
    libvirt-dev build-essential pkg-config rsync

if [[ ! -f /etc/apt/sources.list.d/hashicorp.list ]]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.asc >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.asc] https://apt.releases.hashicorp.com noble main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    sudo apt-get update -qq
fi
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y vagrant
if ! vagrant plugin list | grep -q '^vagrant-libvirt '; then
    vagrant plugin install vagrant-libvirt
fi

if [[ ! -f /etc/apt/sources.list.d/tailscale.list ]]; then
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
        | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
        | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
    sudo apt-get update -qq
fi
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
sudo systemctl enable --now libvirtd tailscaled
sudo usermod -aG libvirt,kvm "${SUDO_USER:-$USER}"

# Relative weights leave CPUs available to either workload when the other is idle.
sudo systemctl set-property user.slice CPUWeight=200
sudo systemctl set-property system.slice CPUWeight=200
sudo systemctl set-property machine.slice CPUWeight=100

for guest in gtm-agent engr-agent pidgey-agent; do
    if sudo virsh -c qemu:///system dominfo "$guest" >/dev/null 2>&1; then
        sudo virsh -c qemu:///system autostart "$guest"
    fi
done
if sudo virsh -c qemu:///system net-info vagrant-libvirt >/dev/null 2>&1; then
    sudo virsh -c qemu:///system net-autostart vagrant-libvirt
fi
systemctl show user.slice system.slice machine.slice -p Id -p CPUWeight -p CPUQuotaPerSecUSec -p MemoryMax
vagrant --version
vagrant plugin list
