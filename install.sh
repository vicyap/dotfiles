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

import_atuin_history() {
    if ! has_cmd atuin; then
        echo "  Skipped: atuin not installed"
        return 0
    fi

    local db="${XDG_DATA_HOME:-$HOME/.local/share}/atuin/history.db"
    if [[ -f "$db" ]]; then
        echo "  ok history already imported"
        return 0
    fi

    if [[ -f "$HOME/.zsh_history" ]]; then
        atuin import zsh && echo "  + imported zsh history"
    else
        echo "  ok no zsh history to import"
    fi
}

# Hosts whose user environment is managed by Nix/home-manager. As a host is
# migrated, add it here; install.sh activates home-manager only on these. zsh
# plugins (fzf-tab, autosuggestions, syntax-highlighting) and tmux plugins
# (resurrect, continuum) are now declared in the flake, so the old git-clone
# installers are gone.
NIX_MANAGED_HOSTS=(rhinestone)

install_nix() {
    if has_cmd nix; then
        echo "  ok nix already installed"
        return 0
    fi
    echo "  Installing Nix (NixOS installer, flakes enabled)..."
    curl -sSfL https://artifacts.nixos.org/nix-installer \
        | sh -s -- install --no-confirm --enable-flakes \
        || {
            echo "  Warning: nix install failed"
            return 0
        }
    # Load nix into the current shell so the switch below can run.
    if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        # shellcheck disable=SC1091
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
}

cleanup_relocated_nix_symlinks() {
    # home-manager relocates some configs to XDG paths (git -> ~/.config/git,
    # tmux -> ~/.config/tmux). Remove the old bash-symlinker links at the legacy
    # paths so the new home-manager config isn't shadowed or, for tmux, doesn't
    # re-trigger TPM via ~/.tmux.conf.local. Only ever touch a symlink that
    # points into the dotfiles repo — never a user's real file.
    local p tgt
    for p in "$HOME/.gitconfig" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local"; do
        [[ -L "$p" ]] || continue
        tgt="$(readlink "$p")"
        if [[ "$tgt" == "$DOTFILES_DIR"/* ]]; then
            rm -f "$p"
            echo "  - removed legacy symlink $p (relocated by home-manager)"
        fi
    done
}

setup_home_manager() {
    local host attr managed=0 h
    host="$(hostname -s 2>/dev/null || hostname)"
    for h in "${NIX_MANAGED_HOSTS[@]}"; do
        [[ "$host" == "$h" ]] && managed=1 && break
    done
    if ((managed == 0)); then
        echo "  Skipped: $host is not a nix-managed host"
        return 0
    fi

    install_nix
    has_cmd nix || {
        echo "  Skipped: nix unavailable"
        return 0
    }

    cleanup_relocated_nix_symlinks

    attr="victor@${host}"
    echo "  Activating home-manager for $attr..."
    # -b backup renames any pre-existing file (e.g. an old symlinked ~/.zshrc)
    # instead of failing on the first switch.
    NIX_CONFIG="experimental-features = nix-command flakes" \
        nix run home-manager/release-26.05 -- \
        switch -b backup --flake "${DOTFILES_DIR}#${attr}" \
        || echo "  Warning: home-manager switch failed"

    # Make Nix-provided tools visible to the rest of this run.
    prepend_path "$HOME/.nix-profile/bin"
}

setup_linux_system() {
    # rhinestone-only memory-pressure hardening (zram + disk swapfile + earlyoom).
    # Intentionally host-scoped — see platform/linux/setup-system.sh and the
    # 2026-06-17 postmortem. A no-op on every other machine.
    [[ "$(uname -s)" == "Linux" ]] || {
        echo "  Skipped: not Linux"
        return 0
    }
    [[ "$(hostname -s 2>/dev/null || hostname)" == "rhinestone" ]] \
        || {
            echo "  Skipped: not rhinestone"
            return 0
        }
    has_cmd apt || {
        echo "  Skipped: apt not available"
        return 0
    }

    local script="$DOTFILES_DIR/platform/linux/setup-system.sh"
    [[ -f "$script" ]] || {
        echo "  Skipped: $script not found"
        return 0
    }

    # Needs sudo; run automatically only when sudo won't block on a password
    # prompt (passwordless) or when a human is present to answer it.
    if sudo -n true 2>/dev/null || [[ -t 0 ]]; then
        bash "$script" || echo "  Warning: setup-system.sh did not complete"
    else
        echo "  Skipped: needs sudo — run manually: bash $script"
    fi
}

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
        "usetemi@usetemi"
        "usetemi-private@usetemi-private"
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

setup_codex_plugins() {
    if ! has_cmd codex; then
        echo "  Skipped: codex not installed"
        return 0
    fi

    local marketplaces=(
        "https://github.com/PostHog/ai-plugin.git"
    )

    local marketplace
    for marketplace in "${marketplaces[@]}"; do
        codex plugin marketplace add "$marketplace" \
            || echo "  Skipped: $marketplace marketplace add failed"
    done

    local curated="$HOME/.codex/.tmp/plugins"
    local curated_manifest="$curated/.agents/plugins/marketplace.json"
    local curated_sha="$HOME/.codex/.tmp/plugins.sha"
    if [[ -f "$curated_manifest" ]]; then
        echo "  ok openai-curated marketplace"
    else
        mkdir -p "$(dirname "$curated")"
        if [[ -e "$curated" && ! -d "$curated/.git" ]]; then
            echo "  Skipped: $curated exists and is not a git checkout"
        elif [[ -d "$curated/.git" ]]; then
            git -C "$curated" pull --quiet --ff-only \
                && echo "  ok openai-curated marketplace" \
                || echo "  Skipped: openai-curated marketplace update failed"
        else
            git clone --depth=1 --quiet https://github.com/openai/plugins.git "$curated" \
                && echo "  + openai-curated marketplace" \
                || echo "  Skipped: openai-curated marketplace clone failed"
        fi
    fi
    if [[ -f "$curated_manifest" && -d "$curated/.git" ]]; then
        git -C "$curated" rev-parse HEAD >"$curated_sha" \
            || echo "  Skipped: openai-curated marketplace sha update failed"
    fi

    local plugins=(
        "posthog@posthog"
        "linear@openai-curated"
        "google-calendar@openai-curated"
        "gmail@openai-curated"
        "slack@openai-curated"
        "stripe@openai-curated"
        "vercel@openai-curated"
        "github@openai-curated"
        "google-drive@openai-curated"
        "build-ios-apps@openai-curated"
        "build-macos-apps@openai-curated"
        "build-web-apps@openai-curated"
        "expo@openai-curated"
        "semrush@openai-curated"
        "openai-developers@openai-curated"
    )

    local plugin
    for plugin in "${plugins[@]}"; do
        codex plugin add "$plugin" \
            || echo "  Skipped: $plugin install failed"
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
        "usetemi/skills"
    )

    for registry in "${registries[@]}"; do
        npx --yes skills add "$registry" \
            --global \
            --yes || echo "  Skipped: $registry install failed"
    done
}

# Skills to remove from ~/.agents/skills after registry installs run.
# Registries are installed in full to auto-pick up new upstream skills, so
# opt-outs are listed here and pruned after install.
AGENT_SKILL_EXCLUDES=(
    agent-email-inbox
    email-best-practices
    resend-cli
    template-skill
    vercel-react-native-skills
)

prune_excluded_agent_skills() {
    local agents_skills="$HOME/.agents/skills"

    if [[ ! -d "$agents_skills" ]]; then
        return 0
    fi

    local pruned=0
    local name
    for name in "${AGENT_SKILL_EXCLUDES[@]}"; do
        if [[ -e "$agents_skills/$name" ]]; then
            rm -rf "${agents_skills:?}/$name"
            echo "  - $name (excluded)"
            pruned=$((pruned + 1))
        fi
    done

    echo "  Pruned $pruned excluded agent skills"
}

install_codex_skills() {
    echo "  Codex loads shared skills from $HOME/.agents/skills"
    echo "  Usetemi skills are installed by install_agent_skills"
}

sync_dotfiles_agent_skills() {
    local source_skills="$DOTFILES_DIR/packages/agents/.agents/skills"
    local agents_skills="$HOME/.agents/skills"
    local manifest="$HOME/.agents/.dotfiles-skills.txt"

    if [[ ! -d "$source_skills" ]]; then
        echo "  Skipped: $source_skills does not exist"
        return 0
    fi

    mkdir -p "$agents_skills"

    # Names sync copied here last time. Used to prune skills removed from dotfiles
    # without touching skills installed by other means (Anthropic packs, npx skills, etc.).
    local -a previous=()
    if [[ -f "$manifest" ]]; then
        while IFS= read -r name; do
            [[ -n "$name" ]] && previous+=("$name")
        done <"$manifest"
    fi

    # Mirror current source.
    local mirrored=0
    local -a current=()
    local entry name
    for entry in "$source_skills"/*/; do
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"
        [[ "$name" == .* ]] && continue

        rm -rf "${agents_skills:?}/$name"
        cp -R -L -p "$entry" "$agents_skills/$name"
        current+=("$name")
        mirrored=$((mirrored + 1))
    done

    # Remove dirs we copied previously that are no longer in source.
    local prev keep removed=0
    for prev in "${previous[@]}"; do
        keep=false
        for name in "${current[@]}"; do
            if [[ "$name" == "$prev" ]]; then
                keep=true
                break
            fi
        done
        if ! $keep && [[ -d "$agents_skills/$prev" ]]; then
            rm -rf "${agents_skills:?}/$prev"
            removed=$((removed + 1))
            echo "  - $prev (removed from dotfiles)"
        fi
    done

    # Record what we own now so the next sync can detect future removals.
    if ((${#current[@]} > 0)); then
        printf '%s\n' "${current[@]}" | sort >"$manifest"
    else
        : >"$manifest"
    fi

    echo "  Synced $mirrored dotfiles agent skills into $agents_skills (pruned $removed stale)"
}

sync_claude_rules() {
    local agents_rules="$HOME/.agents/rules"
    local claude_rules="$HOME/.claude/rules"
    local manifest="$HOME/.claude/.dotfiles-rules.txt"
    local old_rules="$DOTFILES_DIR/packages/claude/.claude/rules"

    if [[ ! -d "$agents_rules" ]]; then
        echo "  Skipped: $agents_rules does not exist"
        return 0
    fi

    mkdir -p "$claude_rules"

    local -a previous=()
    if [[ -f "$manifest" ]]; then
        local prev_name
        while IFS= read -r prev_name; do
            [[ -n "$prev_name" ]] && previous+=("$prev_name")
        done <"$manifest"
    fi

    local linked=0
    local skipped=0
    local -a current=()
    local entry name target current_link target_name
    for entry in "$agents_rules"/*; do
        [[ -f "$entry" || -L "$entry" ]] || continue
        name="$(basename "$entry")"
        [[ "$name" == .* ]] && continue

        target="$claude_rules/$name"
        current+=("$name")

        if [[ -L "$target" ]]; then
            current_link="$(readlink "$target")"
            if [[ "$current_link" == "$agents_rules/$name" ]]; then
                echo "  ok $name"
                linked=$((linked + 1))
                continue
            fi

            if [[ "$current_link" == "$old_rules/$name" ]]; then
                rm -f "$target"
            else
                echo "  Skipped: $target points to $current_link"
                skipped=$((skipped + 1))
                continue
            fi
        elif [[ -e "$target" ]]; then
            echo "  Skipped: $target exists and is not a dotfiles-managed symlink"
            skipped=$((skipped + 1))
            continue
        fi

        ln -s "$agents_rules/$name" "$target"
        echo "  + $name"
        linked=$((linked + 1))
    done

    local prev keep stale_removed=0
    for prev in "${previous[@]}"; do
        keep=false
        for name in "${current[@]}"; do
            if [[ "$name" == "$prev" ]]; then
                keep=true
                break
            fi
        done

        target="$claude_rules/$prev"
        if ! $keep && [[ -L "$target" ]]; then
            current_link="$(readlink "$target")"
            if [[ "$current_link" == "$agents_rules/$prev" || "$current_link" == "$old_rules/$prev" ]]; then
                rm -f "$target"
                echo "  - $prev (stale)"
                stale_removed=$((stale_removed + 1))
            fi
        fi
    done

    # First migration run may not have a manifest yet. Clean up old
    # dotfiles-owned Claude rule links whose source files moved or were folded
    # into AGENTS.md.
    for entry in "$claude_rules"/*; do
        [[ -L "$entry" ]] || continue
        name="$(basename "$entry")"
        current_link="$(readlink "$entry")"
        [[ "$current_link" == "$old_rules/"* ]] || continue

        keep=false
        for target_name in "${current[@]}"; do
            if [[ "$name" == "$target_name" ]]; then
                keep=true
                break
            fi
        done

        if ! $keep; then
            rm -f "$entry"
            echo "  - $name (legacy)"
            stale_removed=$((stale_removed + 1))
        fi
    done

    if ((${#current[@]} > 0)); then
        printf '%s\n' "${current[@]}" | sort >"$manifest"
    else
        : >"$manifest"
    fi

    echo "  Synced $linked Claude Code rule links (skipped $skipped, pruned $stale_removed stale)"
}

sync_claude_skills() {
    local claude_skills="$HOME/.claude/skills"
    local agents_skills="$HOME/.agents/skills"

    if [[ ! -d "$agents_skills" ]]; then
        echo "  Skipped: $agents_skills does not exist"
        return 0
    fi

    # Convert directory symlink to real directory
    if [[ -L "$claude_skills" ]]; then
        rm -f "$claude_skills"
    fi
    mkdir -p "$claude_skills"

    # Mirror the shared skills root into Claude Code's native skills directory.
    # skills.sh uses .skill-lock.json pluginName as package metadata (for example
    # usetemi/skills -> pluginName=usetemi), not as Claude Code plugin ownership.
    local name
    for entry in "$agents_skills"/*/; do
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"

        # Skip hidden dirs (.system is Codex-only)
        [[ "$name" == .* ]] && continue

        local target="$claude_skills/$name"

        # Create or verify symlink
        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$agents_skills/$name" ]]; then
            echo "  ok $name"
        else
            if [[ -e "$target" && ! -L "$target" ]]; then
                echo "  Skipped: $target exists and is not a symlink"
                continue
            fi
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

    # Activate home-manager (Nix-managed hosts only). Owns the CLI tool set,
    # shell, git, tmux, etc. symlink_all_packages below skips NIX_OWNED_PACKAGES.
    echo "=== Activating home-manager ==="
    setup_home_manager
    echo

    # Symlink packages
    echo "=== Symlinking packages ==="
    symlink_all_packages "$DOTFILES_DIR/packages"
    echo

    # rhinestone-only: graceful memory-pressure handling (zram + swapfile + earlyoom)
    echo "=== Configuring memory safety (rhinestone) ==="
    setup_linux_system
    echo

    # Link shared agent rules into Claude Code's native path-scoped rules dir.
    echo "=== Syncing Claude Code rules ==="
    sync_claude_rules
    echo

    # Migrate skill config dirs from old internal paths to current public paths
    echo "=== Migrating skill config directories ==="
    migrate_skill_configs
    echo

    # Generate codex config from base + local parts
    echo "=== Generating codex config ==="
    generate_codex_config
    echo

    # Install Codex plugins after config generation, since config.toml is rewritten above.
    echo "=== Installing Codex plugins ==="
    setup_codex_plugins
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
        mise run setup:tmux-status
        mise run setup:shfmt
        echo

        echo "=== Importing atuin history ==="
        import_atuin_history
        echo
    fi

    # Install agent skills (shared across Claude and Codex via ~/.agents/skills).
    echo "=== Installing agent skills ==="
    install_agent_skills
    echo

    # Codex loads the shared skills installed above from ~/.agents/skills.
    echo "=== Installing Codex skills ==="
    install_codex_skills
    echo

    # Keep dotfiles-owned skills as real files in ~/.agents/skills so Codex
    # and Claude both load from the same runtime tree.
    echo "=== Syncing dotfiles agent skills ==="
    sync_dotfiles_agent_skills
    echo

    # Remove skills opted out via AGENT_SKILL_EXCLUDES, after registry installs.
    echo "=== Pruning excluded agent skills ==="
    prune_excluded_agent_skills
    echo

    # Sync shared skills into Claude Code's native skills directory.
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
