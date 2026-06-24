# nixtest VM

Throwaway Ubuntu 24.04 guest for validating the Nix/home-manager migration
without touching the live rhinestone home.

`provision.sh` installs base deps, a `victor` user (home `/home/victor`, to
mirror rhinestone), upstream Nix (NixOS community installer, flakes enabled),
and a copy of the dotfiles repo at `/home/victor/.dotfiles`.

## Create

```bash
cd vms/nixtest
vagrant up --provider=libvirt
```

## Apply the generic Ubuntu home config

```bash
vagrant ssh nixtest
sudo -iu victor
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix run github:nix-community/home-manager/release-26.05 -- \
  switch -b backup --impure --flake /home/victor/.dotfiles#ubuntu-x86_64-linux
# run it again: second run should be a no-op (idempotency check)
home-manager switch --impure --flake /home/victor/.dotfiles#ubuntu-x86_64-linux
```

## Re-test after editing the flake on the host

```bash
cd vms/nixtest
vagrant rsync                       # push host repo changes into the guest
vagrant ssh -c 'sudo cp -a /home/vagrant/dotfiles-src/. /home/victor/.dotfiles/ \
  && sudo chown -R victor:victor /home/victor/.dotfiles'
# then re-run the switch as victor
```

## Destroy

```bash
vagrant destroy -f
```
