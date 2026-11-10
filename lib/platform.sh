#!/usr/bin/env bash
# Platform detection and package installation helpers

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

detect_linux_id() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

detect_supported_platform() {
    case "$(detect_os)" in
        macos)
            echo "macos"
            ;;
        linux)
            if [[ "$(detect_linux_id)" == "ubuntu" ]]; then
                echo "ubuntu"
            else
                echo "unsupported-linux"
            fi
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

require_supported_platform() {
    case "$(detect_supported_platform)" in
        macos | ubuntu)
            return 0
            ;;
        unsupported-linux)
            echo "Unsupported Linux distribution: $(detect_linux_id). This repo supports Ubuntu Linux and macOS."
            return 1
            ;;
        *)
            echo "Unsupported OS: $(uname -s). This repo supports Ubuntu Linux and macOS."
            return 1
            ;;
    esac
}

detect_nix_system() {
    case "$(uname -s):$(uname -m)" in
        Darwin:arm64) echo "aarch64-darwin" ;;
        Darwin:x86_64) echo "x86_64-darwin" ;;
        Linux:x86_64) echo "x86_64-linux" ;;
        Linux:aarch64 | Linux:arm64) echo "aarch64-linux" ;;
        *) echo "unknown" ;;
    esac
}

# Ubuntu needs zsh and vim from apt before home-manager has run: zsh as the
# login shell, vim so editor prompts do not fall back to nano. macOS ships both.
# Usage: ensure_apt_command <command> (the apt package has the same name)
ensure_apt_command() {
    local cmd="$1"
    if has_cmd "$cmd"; then
        echo "✓ $cmd already installed"
        return 0
    fi
    [[ "$(detect_os)" == "linux" ]] || return 0

    echo "Installing $cmd..."
    { sudo apt-get update \
        && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$cmd"; } \
        || echo "  Warning: $cmd install failed"
}

# Set zsh as default shell
set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"

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

# Set vim/vi as the default system editor on Linux
set_default_editor() {
    if [[ "$(detect_os)" != "linux" ]]; then
        return 0
    fi

    if ! has_cmd update-alternatives; then
        echo "  Skipped: update-alternatives not found"
        return 0
    fi

    local current
    current="$(update-alternatives --query editor 2>/dev/null | awk -F': ' '/^Value: /{print $2}')"
    if [[ "$current" == *vim* || "$current" == */vi ]]; then
        echo "✓ default editor already set to $current"
        return 0
    fi

    local alternatives candidate
    alternatives="$(update-alternatives --list editor 2>/dev/null || true)"
    for candidate in /usr/bin/vim.basic /usr/bin/vim /usr/bin/vim.tiny /bin/vim /usr/bin/vi /bin/vi; do
        if grep -qxF "$candidate" <<<"$alternatives"; then
            echo "Setting default editor to $candidate..."
            sudo update-alternatives --set editor "$candidate"
            echo "✓ Default editor set to $candidate"
            return 0
        fi
    done

    echo "  Skipped: no vim/vi editor alternative found"
}

# Install mise version manager
install_mise() {
    if has_cmd mise; then
        echo "✓ mise already installed"
        return 0
    fi

    echo "Installing mise..."
    if has_cmd brew; then
        brew install mise
    else
        curl -fsSL https://mise.run | sh && export PATH="$HOME/.local/bin:$PATH"
    fi || {
        echo "  Warning: mise install failed"
        return 0
    }
    echo "✓ mise installed"
}

install_ubuntu_packages() {
    local pkgfile="$1"
    local package available=() unavailable=()

    sudo apt-get update || echo "  Warning: apt-get update failed; using cached package lists"

    while IFS= read -r package; do
        if apt-cache show "$package" >/dev/null 2>&1; then
            available+=("$package")
        else
            unavailable+=("$package")
        fi
    done < <(awk 'NF && $1 !~ /^#/ { print $1 }' "$pkgfile")

    if ((${#available[@]} > 0)); then
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${available[@]}" \
            || echo "  Warning: apt package install failed"
    fi

    if ((${#unavailable[@]} > 0)); then
        echo "  Skipped unavailable apt packages: ${unavailable[*]}"
    fi
}

# Install platform-specific packages
install_platform_packages() {
    local dotfiles_dir="${1:-$HOME/.dotfiles}"
    local platform
    platform="$(detect_supported_platform)"

    case "$platform" in
        macos)
            local brewfile="$dotfiles_dir/platform/macos/Brewfile"
            if [[ -f "$brewfile" ]] && has_cmd brew; then
                echo "Installing Homebrew packages..."
                brew bundle --file="$brewfile" \
                    || echo "  Warning: brew bundle failed"
            fi
            ;;
        ubuntu)
            local pkgfile="$dotfiles_dir/platform/linux/packages.txt"
            if [[ -f "$pkgfile" ]] && has_cmd apt-get; then
                echo "Installing apt packages..."
                install_ubuntu_packages "$pkgfile"
            fi
            ;;
    esac
}
