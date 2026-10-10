#!/usr/bin/env bash
# Post-activation verification for the nix-darwin lima config. Run on the
# darwintest guest after `darwin-rebuild switch --flake .#lima`. Needs sudo
# (reads the primaryUser's per-user defaults and home). Usage: verify.sh [user]
set -uo pipefail
u="${1:-victoryap}"
home="/Users/$u"

echo "== current system generation =="
readlink /run/current-system || echo "  MISSING"

echo "== system.defaults (as $u) =="
printf '  dock.autohide            = %s\n' "$(sudo -u "$u" defaults read com.apple.dock autohide 2>/dev/null || echo '?')"
printf '  finder.AllExtensions     = %s\n' "$(sudo -u "$u" defaults read com.apple.finder AppleShowAllExtensions 2>/dev/null || echo '?')"
printf '  NSGlobal.InitialKeyRepeat = %s\n' "$(sudo -u "$u" defaults read -g InitialKeyRepeat 2>/dev/null || echo '?')"

echo "== home-manager symlinks (-> /nix/store) =="
for f in .zshrc .vimrc .config/git/config; do
    printf '  %-22s -> %s\n' "$f" "$(readlink "$home/$f" 2>/dev/null || echo MISSING)"
done

echo "== /etc/zshrc managed by nix-darwin =="
printf '  /etc/zshrc -> %s\n' "$(readlink /etc/zshrc 2>/dev/null || echo '?')"
[ -e /etc/zshrc.before-nix-darwin ] && echo "  original backed up: /etc/zshrc.before-nix-darwin"

echo "== nix-profile tools for $u =="
for t in starship fd bat eza atuin zoxide just direnv; do
    if [ -e "$home/.nix-profile/bin/$t" ]; then printf '  %-10s ok\n' "$t"; else printf '  %-10s MISSING\n' "$t"; fi
done

echo "== Homebrew casks (run brew as $u; brew must be owned by $u) =="
sudo -u "$u" -H /opt/homebrew/bin/brew list --cask 2>/dev/null | sed 's/^/  /' || echo "  (brew not available / not owned by $u)"
