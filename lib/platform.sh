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

# Ensure ~/go/bin is in PATH (added to shell rc files)
ensure_go_path() {
  local go_bin="$HOME/go/bin"
  local path_line="export PATH=\"$go_bin:\$PATH\""

  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$rcfile" ]] && ! grep -q "$go_bin" "$rcfile" 2>/dev/null; then
      echo "" >> "$rcfile"
      echo "# Go binaries" >> "$rcfile"
      echo "$path_line" >> "$rcfile"
      echo "✓ Added $go_bin to PATH in $(basename "$rcfile")"
    fi
  done

  # Also export for current session
  export PATH="$go_bin:$PATH"
}

# Install or update Go to version specified in versions.conf
install_go() {
  local desired_version
  desired_version="$(get_desired_version go)"

  if [[ -z "$desired_version" ]]; then
    echo "⚠ No Go version specified in versions.conf"
    return 0
  fi

  local installed_version
  installed_version="$(get_installed_version go)"

  if [[ "$installed_version" == "$desired_version" ]]; then
    echo "✓ Go $desired_version already installed"
    return 0
  fi

  echo "Installing Go $desired_version (current: ${installed_version:-none})..."

  case "$(detect_os)" in
    macos)
      if has_cmd brew; then
        # Homebrew manages Go versions
        brew install go || brew upgrade go
      else
        echo "⚠ Please install Homebrew first: https://brew.sh"
        return 1
      fi
      ;;
    linux)
      local arch
      case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv*)   arch="armv6l" ;;
        *)       echo "⚠ Unsupported architecture: $(uname -m)"; return 1 ;;
      esac

      local tarball="go${desired_version}.linux-${arch}.tar.gz"
      local url="https://go.dev/dl/${tarball}"

      echo "Downloading $url..."
      curl -fsSL "$url" -o "/tmp/$tarball"

      # Remove existing Go installation
      sudo rm -rf /usr/local/go

      # Extract new version
      sudo tar -C /usr/local -xzf "/tmp/$tarball"
      rm -f "/tmp/$tarball"

      # Ensure /usr/local/go/bin is in PATH
      if ! grep -q "/usr/local/go/bin" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.zshrc"
      fi
      if ! grep -q "/usr/local/go/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.bashrc"
      fi
      export PATH="/usr/local/go/bin:$PATH"
      ;;
    *)
      echo "⚠ Unknown OS, please install Go manually"
      return 1
      ;;
  esac

  echo "✓ Go $(go version 2>/dev/null | awk '{print $3}' | sed 's/go//') installed"
  ensure_go_path
}

# Install or update web CLI (requires Go)
# Note: Must build from source since go.mod declares module as "web" not "github.com/chrismccord/web"
install_web() {
  local desired_version
  desired_version="$(get_desired_version web)"

  if [[ -z "$desired_version" ]]; then
    echo "⚠ No web version specified in versions.conf"
    return 0
  fi

  # Ensure Go is available
  if ! has_cmd go; then
    echo "⚠ Go is required to install web CLI. Installing Go first..."
    install_go || return 1
  fi

  # Ensure go bin is in PATH for current session
  export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

  local web_repo="https://github.com/chrismccord/web.git"
  local web_dir="/tmp/web-cli-build"

  echo "Installing web CLI (from source)..."

  # Clone or update repo
  if [[ -d "$web_dir" ]]; then
    git -C "$web_dir" fetch --quiet
    git -C "$web_dir" reset --hard origin/main --quiet
  else
    git clone --quiet "$web_repo" "$web_dir"
  fi

  # Build and install
  (cd "$web_dir" && go build -o "$HOME/go/bin/web" .) || {
    echo "⚠ Failed to build web CLI"
    return 1
  }

  # Cleanup
  rm -rf "$web_dir"

  echo "✓ web CLI installed"
  ensure_go_path
}

# Install or update ask CLI (Kagi search CLI)
# Requires: curl, jq, bc
install_ask() {
  local desired_version
  desired_version="$(get_desired_version ask)"

  if [[ -z "$desired_version" ]]; then
    echo "⚠ No ask version specified in versions.conf"
    return 0
  fi

  local bin_dir="$HOME/.local/bin"
  local ask_path="$bin_dir/ask"

  # Check if already installed (for non-latest versions)
  if [[ "$desired_version" != "latest" ]] && [[ -x "$ask_path" ]]; then
    echo "✓ ask CLI already installed"
    return 0
  fi

  # Ensure dependencies are available
  local missing_deps=()
  for dep in curl jq bc; do
    if ! has_cmd "$dep"; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Installing ask dependencies: ${missing_deps[*]}..."
    case "$(detect_os)" in
      macos)
        brew install "${missing_deps[@]}"
        ;;
      linux)
        if has_cmd apt; then
          sudo apt update && sudo apt install -y "${missing_deps[@]}"
        elif has_cmd dnf; then
          sudo dnf install -y "${missing_deps[@]}"
        elif has_cmd pacman; then
          sudo pacman -S --noconfirm "${missing_deps[@]}"
        fi
        ;;
    esac
  fi

  echo "Installing ask CLI..."

  # Create bin directory if needed
  mkdir -p "$bin_dir"

  # Download ask script
  curl -fsSL "https://raw.githubusercontent.com/kagisearch/ask/main/ask" -o "$ask_path"
  chmod +x "$ask_path"

  # Ensure ~/.local/bin is in PATH
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$rcfile" ]] && ! grep -q '\.local/bin' "$rcfile" 2>/dev/null; then
      echo "" >> "$rcfile"
      echo '# Local binaries' >> "$rcfile"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rcfile"
      echo "✓ Added ~/.local/bin to PATH in $(basename "$rcfile")"
    fi
  done

  echo "✓ ask CLI installed"
  echo "  Note: Set OPENROUTER_API_KEY environment variable to use ask"
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
