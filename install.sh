#!/usr/bin/env bash
set -e

DOTFILES_REPO="https://github.com/vicyap/dotfiles.git"

# Auto-detect location: use script's directory if running locally, otherwise ~/.dotfiles
if [[ -n "${BASH_SOURCE[0]}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    DOTFILES_DIR="$HOME/.dotfiles"
fi

setup_claude_plugins() {
    if ! has_cmd claude; then
        echo "  Skipped: claude not installed"
        return 0
    fi

    # Custom marketplaces (official is built-in)
    local marketplaces=(
        "openai/codex-plugin-cc"
        "usetemi/skills"
    )

    for marketplace in "${marketplaces[@]}"; do
        claude plugin marketplace add "$marketplace" || true
    done

    # All plugins to install (enable/disable controlled by settings.json)
    local plugins=(
        "commit-commands@claude-plugins-official"
        "code-review@claude-plugins-official"
        "feature-dev@claude-plugins-official"
        "code-simplifier@claude-plugins-official"
        "playwright@claude-plugins-official"
        "typescript-lsp@claude-plugins-official"
        "context7@claude-plugins-official"
        "pr-review-toolkit@claude-plugins-official"
        "pyright-lsp@claude-plugins-official"
        "posthog@claude-plugins-official"
        "linear@claude-plugins-official"
        "claude-md-management@claude-plugins-official"
        "skill-creator@claude-plugins-official"
        "claude-code-setup@claude-plugins-official"
        "explanatory-output-style@claude-plugins-official"
        "codex@openai-codex"
        "temi-skills@usetemi-skills"
    )

    for plugin in "${plugins[@]}"; do
        claude plugin install "$plugin" || true
    done
}

generate_codex_config() {
    local codex_dir="$HOME/.codex"
    local base="$DOTFILES_DIR/packages/codex/.codex/config.base.toml"
    local local_config="$DOTFILES_DIR/packages/codex/.codex/config.local.toml"
    local target="$codex_dir/config.toml"

    if [[ ! -f "$base" ]]; then
        echo "  Skipped: config.base.toml not found"
        return 0
    fi

    mkdir -p "$codex_dir"
    rm -f "$target"

    cat "$base" >"$target"
    if [[ -f "$local_config" ]]; then
        printf '\n' >>"$target"
        cat "$local_config" >>"$target"
    fi

    echo "  Generated $target"
}

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

    # Detect platform
    local os
    os="$(detect_os)"
    echo "Detected OS: $os"
    echo

    # Install zsh
    install_zsh
    echo

    # Install mise and dev tools
    echo "=== Installing development tools ==="
    install_mise
    echo

    # Symlink packages
    echo "=== Symlinking packages ==="
    symlink_all_packages "$DOTFILES_DIR/packages"
    echo

    # Generate codex config from base + local parts
    echo "=== Generating codex config ==="
    generate_codex_config
    echo

    # Install Claude Code plugins
    echo "=== Installing Claude Code plugins ==="
    setup_claude_plugins
    echo

    # Install Ghostty terminfo (needed on remotes without Ghostty installed)
    echo "=== Installing terminfo ==="
    tic -x "$DOTFILES_DIR/lib/xterm-ghostty.terminfo"
    echo

    # Install tools via mise (after symlinks so config.toml is in place)
    if has_cmd mise; then
        echo "=== Installing mise tools (Go, Node, Python) ==="
        mise install --yes
        echo

        echo "=== Installing CLI tools ==="
        eval "$(mise activate bash)"
        mise run setup:web
        mise run setup:ask
        mise run setup:ssh-opener
        mise run setup:pyright
        mise run setup:typescript-lsp
        mise run setup:shfmt
        echo
    fi

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
