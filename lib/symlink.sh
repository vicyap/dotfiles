#!/usr/bin/env bash
# Symlink helper functions

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# Force overwrite existing files without prompting
# DOTFILES_FORCE: set to 1 to back up and replace all conflicts
is_force() {
    [[ "$DOTFILES_FORCE" == "1" ]]
}

# Detect if conflict prompts are enabled.
# DOTFILES_INTERACTIVE: never (default), always, auto
is_interactive() {
    case "${DOTFILES_INTERACTIVE:-never}" in
        always)
            return 0
            ;;
        auto)
            [[ -t 0 ]]
            ;;
        never | *)
            return 1
            ;;
    esac
}

# Prompt user for y/n confirmation
# Usage: prompt_user "message" [default: n]
# Returns: 0 for yes, 1 for no
prompt_user() {
    local message="$1"
    local default="${2:-n}"
    local prompt reply

    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    read -r -p "  $message $prompt " reply
    reply="${reply:-$default}"

    [[ "$reply" =~ ^[Yy] ]]
}

# Create a symlink, backing up existing files
# Usage: create_symlink <source> <target>
create_symlink() {
    local src="$1"
    local target="$2"
    local target_dir

    target_dir="$(dirname "$target")"

    # Create parent directory if needed
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi

    # Handle existing file/symlink
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            local current_link
            current_link="$(readlink "$target")"
            if [[ "$current_link" == "$src" ]]; then
                echo "  ✓ $target (already linked)"
                return 0
            fi
            # Symlink points elsewhere - ask before replacing
            if is_force; then
                : # force mode: proceed to replace
            elif is_interactive; then
                if ! prompt_user "Replace $target (currently → $current_link)?"; then
                    echo "  ⊘ Skipped: $target"
                    return 0
                fi
            else
                echo "  ⊘ Skipped (non-interactive): $target"
                return 0
            fi
            rm "$target"
        else
            # Regular file exists - ask before backing up
            if is_force; then
                : # force mode: proceed to backup and replace
            elif is_interactive; then
                if ! prompt_user "Backup and replace $target?"; then
                    echo "  ⊘ Skipped: $target"
                    return 0
                fi
            else
                echo "  ⊘ Skipped (non-interactive): $target"
                return 0
            fi
            echo "  → Backing up: $target"
            mkdir -p "$BACKUP_DIR"
            mv "$target" "$BACKUP_DIR/"
        fi
    fi

    ln -s "$src" "$target"
    echo "  ✓ $target → $src"
}

# Symlink all files in a package directory to $HOME
# Usage: symlink_package <package_path>
symlink_package() {
    local pkg_path="$1"
    # Remove trailing slash if present
    pkg_path="${pkg_path%/}"
    local pkg_name
    pkg_name="$(basename "$pkg_path")"
    local os_name
    os_name="$(uname -s)"

    if [[ ! -d "$pkg_path" ]]; then
        echo "Package not found: $pkg_path"
        return 1
    fi

    echo "[$pkg_name]"

    # Per-package manifest of the rel paths seen on the previous run, so links
    # whose source file was deleted or renamed can be pruned (same
    # previous/current diff pattern as sync_claude_rules in install.sh).
    local manifest_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
    local manifest="$manifest_dir/symlinks-$pkg_name.txt"
    local -a current_rels=()

    # Find all files and symlinks, then link them into $HOME
    while IFS= read -r -d '' file; do
        local rel_path="${file#"$pkg_path"/}"
        local target="$HOME/$rel_path"

        # Top-level Library paths are macOS home config locations.
        if [[ "$rel_path" == Library/* && "$os_name" != "Darwin" ]]; then
            continue
        fi

        # Dotfiles-owned skills are copied into ~/.agents/skills by
        # sync_dotfiles_agent_skills so Codex sees regular SKILL.md files.
        if [[ "$pkg_name" == "agents" && "$rel_path" == .agents/skills/* ]]; then
            continue
        fi

        current_rels+=("$rel_path")

        if [[ -L "$file" ]]; then
            # For symlinks: recreate the same link target at $HOME so relative
            # paths resolve from the runtime location, not the dotfiles repo.
            local link_target
            link_target="$(readlink "$file")"
            local target_dir
            target_dir="$(dirname "$target")"
            [[ -d "$target_dir" ]] || mkdir -p "$target_dir"
            if [[ -L "$target" ]]; then
                local current
                current="$(readlink "$target")"
                if [[ "$current" == "$link_target" ]]; then
                    echo "  ✓ $target (already linked)"
                    continue
                fi
                if is_force; then
                    rm "$target"
                elif is_interactive; then
                    if ! prompt_user "Replace $target (currently → $current)?"; then
                        echo "  ⊘ Skipped: $target"
                        continue
                    fi
                    rm "$target"
                else
                    echo "  ⊘ Skipped (non-interactive): $target"
                    continue
                fi
            elif [[ -e "$target" ]]; then
                if is_force; then
                    mkdir -p "$BACKUP_DIR"
                    mv "$target" "$BACKUP_DIR/"
                elif is_interactive; then
                    if ! prompt_user "Backup and replace $target?"; then
                        echo "  ⊘ Skipped: $target"
                        continue
                    fi
                    mkdir -p "$BACKUP_DIR"
                    mv "$target" "$BACKUP_DIR/"
                else
                    echo "  ⊘ Skipped (non-interactive): $target"
                    continue
                fi
            fi
            ln -s "$link_target" "$target"
            echo "  ✓ $target → $link_target"
        else
            create_symlink "$file" "$target"
        fi
    done < <(find "$pkg_path" \( -type f -o -type l \) -print0)

    # Prune links recorded on a prior run whose source has since been deleted
    # or renamed. Only ever removes a symlink that points into the dotfiles
    # repo AND is dangling — never a real file or a foreign link.
    if [[ -f "$manifest" ]]; then
        local prev still cur target link
        while IFS= read -r prev; do
            [[ -n "$prev" ]] || continue
            still=0
            for cur in "${current_rels[@]}"; do
                if [[ "$cur" == "$prev" ]]; then
                    still=1
                    break
                fi
            done
            [[ "$still" == 1 ]] && continue
            target="$HOME/$prev"
            [[ -L "$target" ]] || continue
            link="$(readlink "$target")"
            if [[ "$link" == "$DOTFILES_DIR"/* && ! -e "$target" ]]; then
                rm -f "$target"
                echo "  - $target (source removed)"
            fi
        done <"$manifest"
    fi

    mkdir -p "$manifest_dir"
    if ((${#current_rels[@]} > 0)); then
        printf '%s\n' "${current_rels[@]}" | sort >"$manifest"
    else
        : >"$manifest"
    fi
}

# Packages whose files are managed by Nix/home-manager instead of symlinks.
# As home-manager takes ownership of a package, add it here (per-file cutover)
# so the bash symlinker and home-manager never fight over the same path.
#
# `shell` (.aliases/.functions) is intentionally NOT here: home-manager bakes
# its content into the generated zsh rc, but .bashrc still sources the symlinked
# files, so the bash symlinker keeps them. There are no `fzf`, `zoxide`, or
# `direnv` package dirs — home-manager owns those three outright, so they're
# intentionally absent from this array; don't add package dirs for them.
NIX_OWNED_PACKAGES=(git vim zsh starship atuin bat tmux)

# Symlink all packages in a directory
# Usage: symlink_all_packages <packages_dir>
symlink_all_packages() {
    local packages_dir="$1"

    for pkg in "$packages_dir"/*/; do
        [[ -d "$pkg" ]] || continue

        local pkg_name owned skip=0
        pkg_name="$(basename "$pkg")"
        for owned in "${NIX_OWNED_PACKAGES[@]}"; do
            if [[ "$pkg_name" == "$owned" ]]; then
                skip=1
                break
            fi
        done
        if [[ "$skip" == 1 ]]; then
            echo "[$pkg_name] managed by home-manager — skipping symlink"
            continue
        fi

        symlink_package "$pkg"
    done
}
