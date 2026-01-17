#!/usr/bin/env bash
set -e

DOTFILES_REPO="https://github.com/vicyap/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

main() {
  echo "=== Dotfiles Installer ==="
  echo

  # Clone or update repo
  if [[ -d "$DOTFILES_DIR" ]]; then
    echo "Updating dotfiles..."
    git -C "$DOTFILES_DIR" pull --rebase --quiet
  else
    echo "Cloning dotfiles..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  # Load helpers
  source "$DOTFILES_DIR/lib/platform.sh"
  source "$DOTFILES_DIR/lib/symlink.sh"
  source "$DOTFILES_DIR/lib/version.sh"

  # Detect platform
  local os
  os="$(detect_os)"
  echo "Detected OS: $os"
  echo

  # Install zsh
  install_zsh
  echo

  # Install Go and web CLI
  echo "=== Installing development tools ==="
  install_go
  install_web
  install_ask
  echo

  # Symlink packages
  echo "=== Symlinking packages ==="
  symlink_all_packages "$DOTFILES_DIR/packages"
  echo

  # Ensure bin is in PATH
  ensure_path

  # Set default shell (only prompt if running interactively)
  if [[ -t 0 ]]; then
    echo
    read -p "Set zsh as default shell? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      set_default_shell
    fi
  fi

  echo
  echo "=== Done! ==="
  echo "Restart your terminal or run: exec zsh"
}

ensure_path() {
  local bin_dir="$DOTFILES_DIR/bin"
  local path_line="export PATH=\"$bin_dir:\$PATH\""

  # Check if already in zshrc
  if ! grep -q "$bin_dir" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# Dotfiles bin" >> "$HOME/.zshrc"
    echo "$path_line" >> "$HOME/.zshrc"
    echo "✓ Added $bin_dir to PATH in .zshrc"
  fi
}

main "$@"
