# darwintest VM

Throwaway macOS guest for validating the nix-darwin migration without touching
the real lima system — the macOS analogue of `vms/nixtest`. nix-darwin activates
as root and writes system-wide state (`system.defaults` plists, `/etc/zshrc`,
Homebrew), so a disposable VM is the safe place to iterate.

macOS guests only run on Apple hardware; lima is Apple Silicon, so this works.
Note: the **Lima** tool (`limactl`) runs Linux guests only and cannot host
macOS — despite the host being named "lima", use `tart` here.

`provision.sh` installs the Xcode CLT, upstream Nix (flakes), and Homebrew (which
nix-darwin's cask module expects to be present). The `darwin-rebuild switch` is
run by hand afterwards.

## Prerequisites

- Apple Silicon Mac (this is lima). Run everything below on lima itself.
- `brew install cirruslabs/cli/tart`
- ~80 GB free disk for the image + Nix store.
- Pick a base image whose macOS version matches lima's, so `system.stateVersion`
  and version-sensitive defaults behave the same. Templates:
  https://github.com/cirruslabs/macos-image-templates

## Create

```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest darwintest
tart run darwintest &           # boots in a window; backgrounded here
IP=$(tart ip darwintest)        # may take a minute to get an address
```

The image's user is `admin` / password `admin`, with passwordless sudo and SSH
enabled. Optional one-time `ssh-copy-id admin@"$IP"` avoids password prompts.

## Provision + apply

```bash
# install Nix + Homebrew in the guest
ssh admin@"$IP" 'bash -s' < provision.sh

# copy this working tree in. Excluding .git makes nix treat the dest as a
# path-flake, so it picks up uncommitted changes (no commit needed to test).
# darwin-rebuild runs as root, so place the repo where the flake's home paths
# resolve (/Users/victoryap/.dotfiles) and chown it to the primary user.
rsync -a --exclude '.git' --exclude 'vms/*/.vagrant' ../../ admin@"$IP":/tmp/dfsrc/
ssh admin@"$IP" 'sudo rsync -a --delete /tmp/dfsrc/ /Users/victoryap/.dotfiles/ \
  && sudo rm -rf /Users/victoryap/.dotfiles/.git \
  && sudo chown -R victoryap:staff /Users/victoryap/.dotfiles'

# first activation (bootstraps darwin-rebuild), then an idempotency re-run
ssh admin@"$IP"
sudo nix run "github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild" -- \
  switch --flake /Users/victoryap/.dotfiles#lima
sudo darwin-rebuild switch --flake /Users/victoryap/.dotfiles#lima   # subsequent runs
```

Build-only gate (realizes the closure, never activates — catches every eval
and option error):

```bash
nix build /Users/victoryap/.dotfiles#darwinConfigurations.lima.system --no-link
```

## Spot-check

```bash
./verify.sh victoryap                    # generation, defaults, hm symlinks, tools, casks
defaults read com.apple.dock | head      # nix-darwin wrote the plist
```

A VM can't exercise hardware/GUI-tied defaults (trackpad, display arrangement,
Touch ID, some Dock/Finder visuals): activation still runs and the plists are
still written, but you can't see the effect headless. `masApps` is unreliable
under Nix regardless.

## Destroy

```bash
tart stop darwintest; tart delete darwintest
```

## Lima specifics (learned from the validation run)

- The `darwinConfigurations` attr is `lima`; the flake's `system.primaryUser`
  and `users.users.victoryap.home` are `victoryap` / `/Users/victoryap`.
- Mirror lima faithfully in the guest: create a `victoryap` user (the base
  image's `admin` stays for sudo/SSH) and set the hostname so a hostname-based
  apply path would also match:

  ```bash
  sudo scutil --set HostName lima
  sudo scutil --set LocalHostName lima
  sudo scutil --set ComputerName lima
  ```

- Homebrew must be owned by the primary user (`victoryap`), not the SSH user.
  nix-darwin runs `brew` as `system.primaryUser`, so if Homebrew was installed
  by `admin`, the cask step fails with `Permission denied` on
  `/opt/homebrew/var/homebrew/locks`. On real lima this is a non-issue (the
  user owns brew); in the guest, `sudo chown -R victoryap:staff /opt/homebrew`.
- Pin the base image to lima's macOS version (Tahoe) so version-sensitive
  defaults and `system.stateVersion` behave the same.

Prefer Vagrant ergonomics? The `vagrant_tart` provider wraps tart with the same
`vagrant up` / `ssh` / `destroy` flow as `vms/nixtest`.
