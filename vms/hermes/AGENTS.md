# Hermes VM

Vagrant + libvirt VM that runs Hermes Agent inside an isolated Ubuntu guest. No
host source or workspace is mounted in. On rhinestone/libvirt, guest `/tmp` is
the sole exception: it is an isolated per-guest directory backed by the host's
volatile tmpfs. Source files live here; generated machine state stays in
`.vagrant/` (gitignored).

- Bring up / enter: `vagrant up --provider=libvirt`, then `vagrant ssh hermes`.
- Hermes installs to `~/.local/bin/hermes` for the `vagrant` user; default
  workspace is `~/workspace`.

The full operational runbook — Signal linking, `hermes setup` answers,
optional host-side SSH backend, and the Xvfb check — is in
[README.md](./README.md). Read it before changing provisioning or setup.
