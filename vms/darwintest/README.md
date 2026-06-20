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

# copy this working tree in (tests uncommitted changes, like vms/nixtest does)
rsync -a --exclude '.git' --exclude 'vms/*/.vagrant' ../../ admin@"$IP":.dotfiles/

# first activation, then an idempotency re-run (second run should report no change)
ssh admin@"$IP"
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix run nix-darwin -- switch --flake ~/.dotfiles#<attr>   # bootstraps darwin-rebuild
darwin-rebuild switch --flake ~/.dotfiles#<attr>
```

Build-only gate (run on lima itself; realizes the closure, never activates):

```bash
nix build ~/.dotfiles#darwinConfigurations.<attr>.system
```

## Spot-check

```bash
defaults read com.apple.dock | head     # nix-darwin wrote the plist
brew list --cask                        # casks present
```

A VM can't exercise hardware/GUI-tied defaults (trackpad, display arrangement,
Touch ID, some Dock/Finder visuals): activation still runs and the plists are
still written, but you can't see the effect headless. `masApps` is unreliable
under Nix regardless.

## Destroy

```bash
tart stop darwintest; tart delete darwintest
```

## To fill in at the lima slice

- `<attr>` — the `darwinConfigurations` name (e.g. `lima`).
- Match the guest username/home to lima's real account (mirror it, the way
  nixtest mirrors `victor` / `/home/victor`), or parameterize the flake's
  `system.primaryUser` and home path so one config targets both the VM's `admin`
  and lima's user.
- Pin the base image to lima's macOS version.

Prefer Vagrant ergonomics? The `vagrant_tart` provider wraps tart with the same
`vagrant up` / `ssh` / `destroy` flow as `vms/nixtest`.
