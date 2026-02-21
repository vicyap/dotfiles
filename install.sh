#!/usr/bin/env bash
set -e

DOTFILES_REPO="https://github.com/vicyap/dotfiles.git"

# Auto-detect location: use script's directory if running locally, otherwise ~/.dotfiles
if [[ -n "${BASH_SOURCE[0]}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  DOTFILES_DIR="$HOME/.dotfiles"
fi

main() {
  echo "=== Dotfiles Installer ==="
  echo

  # If running via curl pipe, clone the repo
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    if [[ -d "$DOTFILES_DIR" ]]; then
      echo "Error: $DOTFILES_DIR exists but is not a git repo"
      exit 1
    fi
    echo "Cloning dotfiles..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  echo "Dotfiles directory: $DOTFILES_DIR"
  echo

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
  echo "Create ~/.secrets for API keys and tokens."
  echo "Restart your terminal or run: exec zsh"
}

main "$@"
