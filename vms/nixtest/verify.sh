#!/usr/bin/env bash
# Post-activation verification for the generic Ubuntu home-manager config. Run on
# the nixtest guest as the mirror user `victor`, after
# `home-manager switch --impure .#ubuntu-x86_64-linux`.
set -uo pipefail
home="$HOME"

echo "== home-manager symlinks (-> /nix/store) =="
for f in .zshrc .config/tmux/tmux.conf .config/git/config .vimrc; do
    printf '  %-26s -> %s\n' "$f" "$(readlink "$home/$f" 2>/dev/null || echo MISSING)"
done

echo "== nix-profile tools =="
for t in starship fd bat eza atuin zoxide just direnv rg; do
    if [ -e "$home/.nix-profile/bin/$t" ]; then printf '  %-10s ok\n' "$t"; else printf '  %-10s MISSING\n' "$t"; fi
done

echo "== generated zsh rc: bindkeys + theme (via zsh -ic) =="
zsh -ic '
  echo "^R -> $(bindkey "^R")"
  echo "^I -> $(bindkey "^I")"
  echo "BAT_THEME=${BAT_THEME:-<unset>}"
' 2>&1 | sed 's/^/  /'

echo "== vim out-of-store symlink target resolves? =="
if ls "$home/.dotfiles/packages/vim/.vimrc" >/dev/null 2>&1; then
    echo "  ok $home/.dotfiles/packages/vim/.vimrc"
else
    echo "  MISSING $home/.dotfiles/packages/vim/.vimrc"
fi
