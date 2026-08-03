# Rhinestone Linux Host Configuration

`setup-system.sh` applies the host-scoped memory-pressure, NVMe-longevity, and
temporary-filesystem policy. It refuses to run anywhere except `rhinestone`.

Rhinestone/libvirt Vagrant definitions should expose only a distinct directory
below `/tmp/rhinestone-vagrant/<machine>/tmp` as guest `/tmp`. Configure it as a
9p synced folder with mapped access and `mount: false`, then mount it from the
guest before any provisioner stages credentials. Other providers should retain
their normal `/tmp`.

The host policy requires the `vagrant-libvirt` network and the `engr-agent`,
`gtm-agent`, and `hermes` domains. `setup-system.sh` fails if any are absent and
enables autostart for all four. Before libvirt starts,
`rhinestone-vagrant-tmpdirs.service` discovers declared source directories from
the private domain XML and recreates only those directories. ACLs admit root,
Victor, and `libvirt-qemu`; one guest never receives the host `/tmp` root or
another guest's directory.

Host slices apply soft pressure without hard resource ceilings: `user.slice`
uses `MemoryHigh=40G`, `machine.slice` uses `MemoryHigh=32G`, and Docker
containers enter `docker.slice` with `MemoryHigh=12G`. All three use
`CPUWeight=75`; `MemoryMax`, swap limits, CPU quotas, and I/O caps remain unset.

Guests own cleanup within their mounted directory and should configure:

```text
D /tmp 1777 root root 7d
```

Temporary credential files may transit the isolated RAM-backed directory during
provisioning. Provisioners must still move them into protected destinations and
remove the staged copies.
