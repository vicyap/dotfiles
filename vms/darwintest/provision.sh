#!/usr/bin/env bash
# Provision a darwintest macOS guest: Xcode command line tools, upstream Nix
# (flakes), and Homebrew. Run inside the guest (see README). The nix-darwin
# activation is run by hand afterwards. Idempotent: each step is a no-op when the
# component is already present.
set -euo pipefail

# Xcode CLT — Homebrew and many builds need it. tart base images usually ship it;
# trigger the install if it is missing.
if ! xcode-select -p >/dev/null 2>&1; then
    echo "==> Installing Xcode command line tools (may open a GUI prompt)..."
    xcode-select --install || true
fi

# Upstream Nix (NixOS installer), multi-user daemon, flakes enabled.
if [ ! -e /nix/var/nix/profiles/default/bin/nix ]; then
    echo "==> Installing Nix..."
    curl -sSfL https://artifacts.nixos.org/nix-installer \
        | sh -s -- install --no-confirm --enable-flakes
fi

# Homebrew — nix-darwin's homebrew module manages casks but expects brew to be
# installed already. Apple Silicon path.
if ! /opt/homebrew/bin/brew --version >/dev/null 2>&1; then
    echo "==> Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "provision complete: copy the repo in and run darwin-rebuild (see README)."
