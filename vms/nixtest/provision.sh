#!/usr/bin/env bash
# Provision the nixtest VM: base deps, a `victor` user mirroring rhinestone's
# home path, upstream Nix, and a copy of the dotfiles repo at
# /home/victor/.dotfiles. The home-manager switch is run by hand afterwards.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    git \
    rsync \
    sudo \
    xz-utils \
    zsh

# Mirror rhinestone: a `victor` user with home /home/victor so the flake's
# absolute home paths (mkOutOfStoreSymlink targets) resolve faithfully.
if ! id victor >/dev/null 2>&1; then
    useradd --create-home --shell /usr/bin/zsh --uid 1100 victor
    printf 'victor ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/victor
    chmod 0440 /etc/sudoers.d/victor
fi

# Place the repo at the path the flake expects, owned by victor.
if [ -d /home/vagrant/dotfiles-src ]; then
    rm -rf /home/victor/.dotfiles
    cp -a /home/vagrant/dotfiles-src /home/victor/.dotfiles
    chown -R victor:victor /home/victor/.dotfiles
fi

# Upstream Nix (NixOS community installer), multi-user daemon, flakes enabled.
if [ ! -e /nix/var/nix/profiles/default/bin/nix ]; then
    curl -sSfL https://artifacts.nixos.org/nix-installer \
        | sh -s -- install linux --no-confirm --enable-flakes
fi

echo "provision complete: run the switch as victor (see README)."
