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

# Host clocks, journal display, and status bars use Pacific time; guests keep their own.
sudo timedatectl set-timezone America/Los_Angeles
# timedatectl leaves the legacy /etc/timezone stale; tzdata rewrites it from /etc/localtime.
sudo dpkg-reconfigure -f noninteractive tzdata
sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl git jq qemu-system-x86 libvirt-daemon-system libvirt-clients \
    libvirt-dev build-essential pkg-config rsync nftables

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo bash "$script_dir/setup-kanto-memory.sh"
sudo install -m 0644 "$script_dir/etc/kanto-firewall.nft" /etc/kanto-firewall.nft
sudo nft --check -f /etc/kanto-firewall.nft
sudo install -m 0644 "$script_dir/etc/systemd/system/kanto-firewall.service" \
    /etc/systemd/system/kanto-firewall.service
# The unaddressed secondary NIC must not hold up network-online.target.
sudo netplan set --origin-hint=90-kanto ethernets.eno2.optional=true
sudo netplan generate
sudo systemctl daemon-reload
sudo systemctl enable kanto-firewall.service
sudo systemctl reload-or-restart kanto-firewall.service
sudo bash "$script_dir/setup-kanto-monitoring.sh"

if [[ ! -f /etc/apt/sources.list.d/docker.sources ]]; then
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod 0644 /etc/apt/keyrings/docker.asc
    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
fi
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo bash "$script_dir/setup-kanto-docker.sh"

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
if sudo virsh -c qemu:///system pool-info default >/dev/null 2>&1; then
    sudo virsh -c qemu:///system pool-autostart default
fi
if sudo virsh -c qemu:///system net-info vagrant-libvirt >/dev/null 2>&1; then
    sudo virsh -c qemu:///system net-autostart vagrant-libvirt
fi
systemctl show user.slice system.slice machine.slice -p Id -p CPUWeight -p CPUQuotaPerSecUSec -p MemoryMax
vagrant --version
vagrant plugin list
