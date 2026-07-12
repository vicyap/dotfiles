# rhinestone Debian migration

Status: planned for a future maintenance window.

## Decision

Migrate rhinestone from Ubuntu LTS to the latest Debian 13 stable point release
available at execution time. Use a clean installation rather than attempting an
in-place cross-distribution conversion.

Debian is the preferred base because rhinestone is a long-lived, headless host
for KVM, Docker, Tailscale, SSH, tmux, browser automation, and development
workloads. A minimal Debian installation provides the apt/systemd environment
already in use without Snap, Canonical-specific services, or a rolling Ubuntu
HWE kernel. Development-tool freshness remains the responsibility of mise,
Nix, uv, containers, and project environments rather than the host OS.

This is architectural cleanup, not an urgent reliability fix. The existing
Ubuntu installation can remain in service until the migration is prepared and
a suitable maintenance window is available.

## Goals

- Establish a minimal, distribution-neutral Debian host with no desktop,
  printing, audio, Snap, or other workstation services.
- Preserve SSH and Tailscale access, KVM guests, Docker workloads, Incus data,
  local development state, and external mounts.
- Keep host configuration reproducible through the dotfiles installer and
  Home Manager.
- Preserve hardware support for the Ryzen 7 7840HS, Radeon 780M, Intel I225-V,
  Intel AX200, NVMe storage, and APFS DKMS.
- Replace the current memory-pressure configuration with one verified to use
  swap and remain reachable during allocation spikes.
- Define an explicit security-update policy for the Debian host.

## Non-goals

- Changing the operating systems used by existing guests.
- Replacing apt with another system package manager.
- Moving development runtimes out of mise, Nix, or uv.
- Rebuilding applications that already run correctly in containers.
- Migrating lima or any other machine to Debian.

## Current state to preserve

- Ubuntu 24.04.4 on an EFI-booted ext4 root filesystem backed by LVM.
- A separate ext4 `/boot`, vfat `/boot/efi`, and external exFAT `/mnt` volume.
- A CIFS mount at `/cheerleader`.
- Two running libvirt guests with 40 GiB of configured memory between them;
  libvirt currently holds about 155 GiB of local state.
- Docker workloads including PostgreSQL and MinIO, plus local Docker volumes
  and networks.
- Incus state under `/var/lib/incus`; determine whether the installed LXD Snap
  contains any unique state before removing it from the migration scope.
- Tailscale SSH and Funnel as remote access and public ingress paths.
- Host-specific zram, swapfile, earlyoom, SSH/Tailscale cgroup protection,
  tmpfs mounts, and CIFS configuration.
- Browser automation through Chrome/Chromium and Xvfb.
- Nix, Home Manager, mise, uv, tmux, and persistent coding-agent sessions.

## Target host

- Latest Debian 13 stable installer and all available updates.
- Debian `main`, `contrib`, `non-free`, and `non-free-firmware` components as
  required by the hardware and installed tools.
- Minimal system utilities and OpenSSH only; no desktop task.
- `systemd-networkd` for continuity with the current host unless testing finds
  a concrete reason to use a different Debian-supported network setup.
- Native Debian packages for QEMU/KVM, libvirt, Incus, earlyoom,
  systemd-zram-generator, APFS DKMS, and general host utilities.
- Official Debian repositories from Docker and Tailscale for their respective
  packages.
- No LXD Snap. Prefer native Incus unless an LXD workload is found during the
  inventory.
- Automatic security updates, or a documented manual cadence chosen before
  cutover.

## Preparation

### 1. Make Debian a supported dotfiles platform

- Add Debian detection and a Debian Home Manager target without changing the
  macOS or Ubuntu paths.
- Audit `platform/linux/packages.txt` against Debian 13 and separate truly
  Ubuntu-specific packages.
- Port the rhinestone system setup without assuming Ubuntu package names,
  repository suites, Netplan, or Ubuntu service defaults.
- Replace Ubuntu-specific third-party repository definitions with Debian
  equivalents for Docker, Tailscale, HashiCorp, Chrome, and any remaining
  vendor packages.
- Decide how to preserve the current Neovim 0.12 track; Debian 13's native
  package is older and the Ubuntu PPA cannot be carried over.
- Confirm the intended Vagrant source. Debian's native Vagrant package is
  older than the current HashiCorp package, so do not substitute it silently.
- Run the complete installer and verification workflow in a fresh Debian 13
  libvirt guest.

### 2. Inventory and back up state

- Record installed packages, enabled services, apt repositories, mounts,
  firewall rules, Tailscale state, timers, cron jobs, sysctls, kernel modules,
  DKMS modules, user groups, and files under `/etc` that differ from package
  defaults.
- Export all libvirt domain, network, pool, and autostart definitions.
- Back up every libvirt disk image and verify its checksum from the backup
  destination.
- Inventory Docker Compose projects, images that cannot be reproduced,
  volumes, networks, secrets locations, and published ports.
- Take application-level backups of PostgreSQL and other stateful services in
  addition to volume-level copies.
- Export any Incus or LXD instances and storage pools that contain unique
  state.
- Back up home directories, Nix/mise/uv configuration, machine-local files,
  `/etc`, `/var/lib`, and any state not reconstructed by dotfiles.
- Create either a tested block-level image of the Ubuntu installation or a
  complete file-level recovery set plus Ubuntu installation media.
- Perform sample restores before accepting the backups.

### 3. Make virtual machines portable

The running guests currently use the Ubuntu-specific QEMU machine type
`pc-i440fx-noble-v2`, which Debian QEMU may not provide.

- Inspect the persistent XML for every guest and identify all Ubuntu-specific
  machine types, firmware paths, emulator paths, AppArmor assumptions, and
  network definitions.
- Select a machine type supported by both the current host and Debian 13.
- Test converted definitions against cloned disks in a disposable environment.
- Confirm clean boot, networking, storage, guest-agent behavior, and shutdown
  before modifying the production definitions.
- Preserve the original XML with the backups.

### 4. Prove remote recovery

- Prepare bootable Debian and Ubuntu recovery media.
- Arrange local console and keyboard access for the installation. Do not
  attempt the destructive reinstall solely over SSH without independent
  console access.
- Record the LAN address, interface MAC, current firmware settings, Secure Boot
  state, and boot order.
- Verify that lima can reach rhinestone over LAN SSH independently of
  Tailscale before the maintenance window.
- Define the exact point at which a failed migration triggers restoration of
  the Ubuntu image.

## Cutover

1. Announce the maintenance window and prevent new work from starting.
2. Stop public ingress and application writers.
3. Take final database dumps and stateful-service backups.
4. Shut down Docker, Incus/LXD, and every libvirt guest cleanly.
5. Take final copies and checksums of changed disks and volumes.
6. Confirm the recovery media, verified backups, and local console are
   available. Require explicit approval before erasing or repartitioning the
   internal NVMe drive.
7. Disconnect or otherwise protect the external `/mnt` drive during
   installation.
8. Install minimal Debian 13, preserving an EFI-compatible layout and using
   the storage design chosen during preparation.
9. Apply all Debian updates and install firmware, OpenSSH, sudo, and the chosen
   networking configuration.
10. Establish LAN SSH from lima, then install and authenticate Tailscale.
    Confirm both access paths before removing local console access.
11. Install Nix and run the Debian-capable dotfiles convergence path.
12. Restore external mounts and verify read/write behavior before restoring
    services that depend on them.
13. Install and configure libvirt, restore portable guest definitions and
    disks, then boot one guest at a time.
14. Install Docker and restore Compose projects, networks, volumes, and
    application-level data.
15. Restore Incus only if the preparation inventory found active state.
16. Restore Caddy, Tailscale Funnel, browser automation, timers, and remaining
    host services.
17. Apply the new memory-pressure configuration and complete validation before
    returning the host to normal use.

## Memory-pressure redesign

Do not carry `vm.swappiness=0` over unchanged. On Ubuntu, kernel OOM kills
occurred while the full 80 GiB swap pool remained free, including repeated
kills on July 9 and 10, 2026. The policy did not provide the intended emergency
cushion during rapid allocation spikes.

- Select a low nonzero swappiness value through testing rather than assumption.
- Keep zram as the high-priority first swap tier and the disk swapfile as the
  slower emergency tier.
- Re-evaluate earlyoom thresholds and the decision to exclude every QEMU
  process when guests reserve most of the host's physical memory.
- Preserve SSH and Tailscale cgroup memory protection and verify it works with
  Debian's systemd version and unit layout.
- Test a rapid memory-allocation spike while connected through both SSH paths.
- Confirm zram or disk swap receives pages before the kernel invokes the OOM
  killer.
- Confirm the host remains responsive and kills an intended disposable
  workload before access services or guest processes.
- Record the tested values and observations in the tracked system
  configuration.

## Validation

The migration is accepted only when all of the following pass:

- Two consecutive cold boots complete without emergency mode or failed
  required services.
- LAN SSH and Tailscale SSH work after each boot.
- Tailscale Funnel routes the configured public ports to the intended local
  services.
- The Ethernet, Wi-Fi, NVMe, AMD graphics, KVM, zram, APFS, and external-drive
  drivers load without relevant kernel errors.
- KVM acceleration is active and every restored guest boots, obtains network
  connectivity, shuts down cleanly, and honors its autostart setting.
- Docker containers become healthy and PostgreSQL and MinIO data pass
  application-level checks.
- Any restored Incus instances start and retain their expected networking and
  storage.
- `/mnt` and `/cheerleader` mount with the intended ownership and read/write
  behavior.
- Chrome/Chromium automation works under Xvfb without a desktop environment.
- Nix, Home Manager, mise, uv, zsh, tmux, Git, and the coding-agent tools work
  from a new SSH session.
- `dotfiles pull` and the normal convergence path complete successfully.
- Security updates are enabled according to the chosen policy.
- The memory-pressure test uses swap, preserves remote access, and terminates
  only an intended disposable workload.
- `systemctl --failed` contains no unresolved required service failures.

## Rollback

- Keep the verified Ubuntu image, file-level backups, guest disks, database
  dumps, and original libvirt XML unchanged until Debian has passed validation
  and operated through an agreed acceptance period.
- If Debian cannot boot reliably, loses both remote access paths, cannot run a
  required guest or container, or corrupts restored state, stop the migration
  and restore the Ubuntu image.
- Do not treat the original internal disk or the only copy of a VM disk as a
  migration workspace.
- Do not delete or repurpose the rollback media without explicit approval.

## Decisions required before scheduling

- Maintenance window and acceptable downtime.
- Backup destination, restore-test evidence, and rollback retention period.
- Final internal storage layout and whether to retain LVM.
- Neovim and Vagrant package ownership on Debian.
- Whether any LXD Snap state must be migrated to Incus.
- Automatic versus explicitly scheduled security updates.
- Tested swappiness, earlyoom thresholds, and guest memory policy.

## References

- [Debian 13 release information](https://www.debian.org/releases/trixie/)
- [Debian 13 release notes](https://www.debian.org/releases/trixie/release-notes/)
- [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [Tailscale Debian packages](https://pkgs.tailscale.com/stable/)
- [Debian libvirt package](https://packages.debian.org/stable/libvirt-daemon-system)
- [Debian Incus package](https://packages.debian.org/trixie/incus)
- [Debian APFS DKMS package](https://packages.debian.org/trixie/apfs-dkms)
