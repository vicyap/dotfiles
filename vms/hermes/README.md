# Hermes VM

This Vagrant VM runs Hermes Agent inside an isolated Ubuntu guest.
The host filesystem is not mounted into the VM.
The stable source files live here; generated machine state stays in `.vagrant/`
and is ignored by git.

## Create or Start

```bash
cd vms/hermes
vagrant up --provider=libvirt
vagrant ssh hermes
```

Hermes is installed for the `vagrant` user at `~/.local/bin/hermes`.
The default workspace is `~/workspace`.

## Signal Setup

Link `signal-cli` as a Signal linked device from inside the VM:

```bash
signal-cli -v --log-file /tmp/signal-link.log link -n "Hermes" | tee >(xargs -L 1 qrencode -t ANSIUTF8)
```

Scan the QR code in Signal on your phone:

```text
Signal -> Settings -> Linked Devices -> Link New Device
```

Leave the command running until linking completes.

Run the linked account as a user-level systemd service:

```bash
mkdir -p ~/.config/signal-cli
cat >~/.config/signal-cli/daemon.env <<'ENV'
SIGNAL_CLI_ACCOUNT=+YOURNUMBER
SIGNAL_CLI_HTTP=127.0.0.1:8080
ENV
chmod 600 ~/.config/signal-cli/daemon.env
systemctl --user daemon-reload
systemctl --user enable --now signal-cli.service
```

Check or restart it with:

```bash
systemctl --user status signal-cli.service
systemctl --user restart signal-cli.service
journalctl --user -u signal-cli.service -f
```

## Hermes Setup Answers

Run setup inside the VM:

```bash
hermes setup
```

For the prompts shown after Nous Portal login:

- `Add another credential for same-provider fallback? [y/N]:` enter `N`
- `Terminal backend:` choose `Local - run directly on this machine`
- `Gateway working directory:` enter `/home/vagrant/workspace`
- `Enable sudo support?` enter `N`

Use `Local` because the Hermes process is already running inside the isolated VM.
Do not choose `SSH` unless you intentionally run Hermes on the host machine and
only want its terminal tool to SSH into this VM.

If you are already at the `SSH host (hostname or IP):` prompt on the host
machine, you are configuring host-side Hermes. Cancel that setup, SSH into the
VM, and run `hermes setup` there instead.

## Optional Host-Side SSH Backend

If you do run Hermes on the host machine later and want its terminal backend to
use this VM, use these setup values after `vagrant up`:

- `SSH host`: `127.0.0.1`
- `SSH user`: `vagrant`
- `SSH port`: `2229`
- `SSH private key path`: `<this-directory>/.vagrant/machines/hermes/libvirt/private_key`
- `Test SSH connection?`: `Y`

## Browser/Xvfb

The VM installs Xvfb and browser runtime libraries. Check it with:

```bash
xvfb-run -a xdpyinfo >/dev/null && echo ok
```
