#!/usr/bin/env bash
# Platform detection and package installation helpers

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

# Check if a command exists
has_cmd() {
  command -v "$1" &>/dev/null
}

# Install zsh if not present
install_zsh() {
  if has_cmd zsh; then
    echo "✓ zsh already installed"
    return 0
  fi

  echo "Installing zsh..."
  case "$(detect_os)" in
    macos)
      if has_cmd brew; then
        brew install zsh
      else
        echo "⚠ zsh not found and brew not available (zsh is usually pre-installed on macOS)"
        return 1
      fi
      ;;
    linux)
      if has_cmd apt; then
        sudo apt update && sudo apt install -y zsh
      elif has_cmd dnf; then
        sudo dnf install -y zsh
      elif has_cmd yum; then
        sudo yum install -y zsh
      elif has_cmd pacman; then
        sudo pacman -S --noconfirm zsh
      else
        echo "⚠ Unknown package manager, please install zsh manually"
        return 1
      fi
      ;;
    *)
      echo "⚠ Unknown OS, please install zsh manually"
      return 1
      ;;
  esac
}

# Set zsh as default shell
set_default_shell() {
  local zsh_path
  zsh_path="$(which zsh)"

  if [[ "$SHELL" == "$zsh_path" ]]; then
    echo "✓ zsh is already default shell"
    return 0
  fi

  echo "Setting zsh as default shell..."

  # Ensure zsh is in /etc/shells
  if ! grep -q "^$zsh_path$" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  chsh -s "$zsh_path"
  echo "✓ Default shell changed to zsh (restart terminal to apply)"
}

# Install mise version manager
install_mise() {
  if has_cmd mise; then
    echo "✓ mise already installed"
    return 0
  fi

  echo "Installing mise..."
  case "$(detect_os)" in
    macos)
      if has_cmd brew; then
        brew install mise
      else
        curl https://mise.run | sh
      fi
      ;;
    linux)
      curl https://mise.run | sh
      export PATH="$HOME/.local/bin:$PATH"
      ;;
    *)
      echo "⚠ Unknown OS, please install mise manually: https://mise.jdx.dev"
      return 1
      ;;
  esac

  echo "✓ mise installed"
}

# Install platform-specific packages
install_platform_packages() {
  local dotfiles_dir="${1:-$HOME/.dotfiles}"
  local os
  os="$(detect_os)"

  case "$os" in
    macos)
      local brewfile="$dotfiles_dir/platform/macos/Brewfile"
      if [[ -f "$brewfile" ]] && has_cmd brew; then
        echo "Installing Homebrew packages..."
        brew bundle --file="$brewfile"
      fi
      ;;
    linux)
      local pkgfile="$dotfiles_dir/platform/linux/packages.txt"
      if [[ -f "$pkgfile" ]] && has_cmd apt; then
        echo "Installing apt packages..."
        sudo apt update
        xargs -a "$pkgfile" sudo apt install -y
      fi
      ;;
  esac
}
