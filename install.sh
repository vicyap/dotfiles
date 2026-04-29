#!/usr/bin/env bash
set -e

DOTFILES_REPO="https://github.com/vicyap/dotfiles.git"

# Check if a command exists before lib/platform.sh is available.
has_cmd() {
    command -v "$1" &>/dev/null
}

prepend_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

install_bootstrap_packages() {
    case "$(uname -s)" in
        Linux)
            if ! has_cmd apt; then
                return 0
            fi

            local packages=()
            [[ -f /etc/ssl/certs/ca-certificates.crt ]] || packages+=(ca-certificates)
            has_cmd curl || packages+=(curl)
            has_cmd git || packages+=(git)
            has_cmd zsh || packages+=(zsh)

            if ((${#packages[@]} == 0)); then
                return 0
            fi

            echo "Installing bootstrap packages..."
            sudo apt update
            sudo apt install -y "${packages[@]}"
            echo
            ;;
    esac
}

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
        "usetemi/skills-private"
    )

    for marketplace in "${marketplaces[@]}"; do
        claude plugin marketplace add "$marketplace" || true
    done

    # All plugins to install (enable/disable controlled by settings.json)
    local plugins=(
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
        "skills@usetemi"
        "temi-skills@usetemi-skills"
    )

    for plugin in "${plugins[@]}"; do
        claude plugin install "$plugin" || true
    done

    # Plugins to keep installed but disabled (install auto-enables)
    local disabled=(
        "explanatory-output-style@claude-plugins-official"
    )

    for plugin in "${disabled[@]}"; do
        claude plugin disable "$plugin" || true
    done
}

install_agent_skills() {
    if ! has_cmd npx; then
        echo "  Skipped: npx not installed"
        return 0
    fi

    # Registries installed in full (no --skill filter → auto-picks up new upstream skills)
    local registries=(
        "resend/resend-skills"
    )

    for registry in "${registries[@]}"; do
        npx --yes skills add "$registry" \
            --global \
            --yes || echo "  Skipped: $registry install failed"
    done
}

install_codex_skills() {
    if ! has_cmd npx; then
        echo "  Skipped: npx not installed"
        return 0
    fi

    # Install the full usetemi/skills registry (no --skill filter → picks up new skills).
    npx --yes skills add usetemi/skills \
        --agent codex \
        --global \
        --yes || {
        echo "  Skipped: Codex skills install failed (GitHub auth may be missing)"
        return 0
    }
}

sync_claude_skills() {
    local claude_skills="$HOME/.claude/skills"
    local agents_skills="$HOME/.agents/skills"
    local lock_file="$HOME/.agents/.skill-lock.json"

    if ! has_cmd jq; then
        echo "  Skipped: jq not installed"
        return 0
    fi

    if [[ ! -d "$agents_skills" ]]; then
        echo "  Skipped: $agents_skills does not exist"
        return 0
    fi

    # Convert directory symlink to real directory
    if [[ -L "$claude_skills" ]]; then
        rm -f "$claude_skills"
    fi
    mkdir -p "$claude_skills"

    # Build list of plugin-provided skill names to skip
    local -a skip_skills=()
    if [[ -f "$lock_file" ]]; then
        while IFS= read -r name; do
            skip_skills+=("$name")
        done < <(jq -r '.skills | to_entries[] | select(.value.pluginName != null) | .key' "$lock_file")
    fi

    # Create per-skill symlinks, skipping plugin-provided and .system
    local name skip
    for entry in "$agents_skills"/*/; do
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"

        # Skip hidden dirs (.system is Codex-only)
        [[ "$name" == .* ]] && continue

        local target="$claude_skills/$name"

        # Check if plugin-provided
        skip=false
        for skill in "${skip_skills[@]}"; do
            if [[ "$skill" == "$name" ]]; then
                skip=true
                break
            fi
        done

        if $skip; then
            [[ -L "$target" ]] && rm -f "$target"
            continue
        fi

        # Create or verify symlink
        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$agents_skills/$name" ]]; then
            echo "  ok $name"
        else
            rm -f "$target"
            ln -s "$agents_skills/$name" "$target"
            echo "  + $name"
        fi
    done

    # Remove stale symlinks
    for entry in "$claude_skills"/*; do
        [[ -L "$entry" ]] || continue
        name="$(basename "$entry")"
        if [[ ! -d "$agents_skills/$name" ]]; then
            rm -f "$entry"
            echo "  - $name (stale)"
        fi
    done
}

migrate_skill_configs() {
    # Move config dirs created by the old internal layout to the new public layout.
    # Idempotent: only moves when old exists and new does not.
    local migrations=(
        "$HOME/.config/usetemi/skills/google-drive:$HOME/.config/gdrive"
        "$HOME/.config/usetemi/skills/google-search-console:$HOME/.config/gsc"
    )

    local entry old new
    for entry in "${migrations[@]}"; do
        old="${entry%%:*}"
        new="${entry##*:}"

        if [[ -d "$old" && ! -e "$new" ]]; then
            mkdir -p "$(dirname "$new")"
            mv "$old" "$new"
            echo "  + moved $(basename "$old") → $new"
        elif [[ -d "$old" && -d "$new" ]]; then
            echo "  ! $old and $new both exist — manual review needed"
        else
            echo "  ok $(basename "$new")"
        fi
    done

    # Clean up the now-empty Temi-branded parent directories.
    rmdir "$HOME/.config/usetemi/skills" 2>/dev/null || true
    rmdir "$HOME/.config/usetemi" 2>/dev/null || true
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

    prepend_path "$HOME/go/bin"
    prepend_path "$HOME/.local/bin"
    install_bootstrap_packages

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

    # Install vim before setting it as the default system editor
    install_vim
    echo

    # Prefer vim/vi for system editor prompts on Linux
    echo "=== Configuring default editor ==="
    set_default_editor
    echo

    # Install mise and dev tools
    echo "=== Installing development tools ==="
    install_mise
    echo

    # Symlink packages
    echo "=== Symlinking packages ==="
    symlink_all_packages "$DOTFILES_DIR/packages"
    echo

    # Migrate skill config dirs from old internal paths to current public paths
    echo "=== Migrating skill config directories ==="
    migrate_skill_configs
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

    # Install agent skills (shared across Claude and Codex via ~/.agents/skills).
    echo "=== Installing agent skills ==="
    install_agent_skills
    echo

    # Install Codex skills after mise tools so Node/npx is available on fresh machines.
    echo "=== Installing Codex skills ==="
    install_codex_skills
    echo

    # Sync skills to Claude Code, skipping plugin-provided duplicates
    echo "=== Syncing Claude Code skills ==="
    sync_claude_skills
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

# Only run main when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
