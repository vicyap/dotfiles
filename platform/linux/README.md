# Rhinestone Linux Host Configuration

`setup-system.sh` applies the host-scoped memory-pressure, NVMe-longevity, and
temporary-filesystem policy. It refuses to run anywhere except `rhinestone`.

Rhinestone/libvirt Vagrant definitions should expose only a distinct directory
below `/tmp/rhinestone-vagrant/<machine>/tmp` as guest `/tmp`. Configure it as a
9p synced folder with mapped access and `mount: false`, then mount it from the
guest before any provisioner stages credentials. Other providers should retain
their normal `/tmp`.

The public dotfiles do not contain a VM inventory. Before libvirt autostart,
`rhinestone-vagrant-tmpdirs.service` discovers declared source directories from
the host's private domain XML and recreates only those directories. ACLs admit
root, Victor, and `libvirt-qemu`; one guest never receives the host `/tmp` root
or another guest's directory.

Guests own cleanup within their mounted directory and should configure:

```text
D /tmp 1777 root root 7d
```

Temporary credential files may transit the isolated RAM-backed directory during
provisioning. Provisioners must still move them into protected destinations and
remove the staged copies.
