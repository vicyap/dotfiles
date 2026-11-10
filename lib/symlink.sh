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

# Print manifest entries that are absent from the given current list, for
# sync_claude_rules in install.sh to prune.
# Usage: manifest_stale_entries <manifest_file> [current_entry...]
manifest_stale_entries() {
    local manifest="$1"
    shift
    [[ -f "$manifest" ]] || return 0
    local prev cur found
    while IFS= read -r prev; do
        [[ -n "$prev" ]] || continue
        found=0
        for cur in "$@"; do
            if [[ "$cur" == "$prev" ]]; then
                found=1
                break
            fi
        done
        ((found)) || printf '%s\n' "$prev"
    done <"$manifest"
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

    # Record what this run links so prune_stale_package_links can later
    # remove links whose source is gone.
    local manifest_dir manifest
    manifest_dir="$(package_manifest_dir)"
    manifest="$manifest_dir/symlinks-$pkg_name.txt"
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
        # sync_agent_skills so Codex sees regular SKILL.md files.
        if [[ "$pkg_name" == "agents" && "$rel_path" == .agents/skills/* ]]; then
            continue
        fi

        current_rels+=("$rel_path")

        if [[ -L "$file" ]]; then
            # A symlink in the package is recreated with the same target at
            # $HOME, so relative targets resolve from where the link is used.
            create_symlink "$(readlink "$file")" "$target"
        else
            create_symlink "$file" "$target"
        fi
    done < <(find "$pkg_path" \( -type f -o -type l \) -print0)

    mkdir -p "$manifest_dir"
    if ((${#current_rels[@]} > 0)); then
        printf '%s\n' "${current_rels[@]}" | sort >"$manifest"
    else
        : >"$manifest"
    fi
}

# Packages the symlinker must not deploy, because home-manager does. Each
# one's nix/home/features/<name>.nix says how its files are used: read at build
# time (zsh, shell, starship, atuin, bat, tmux), which needs a home-manager
# switch to take effect, or linked live out of the store (vim, lazygit,
# fastfetch).
NIX_OWNED_PACKAGES=(vim zsh shell starship atuin bat tmux lazygit fastfetch)

is_nix_owned_package() {
    local owned
    for owned in "${NIX_OWNED_PACKAGES[@]}"; do
        [[ "$1" == "$owned" ]] && return 0
    done
    return 1
}

package_manifest_dir() {
    echo "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
}

# Remove links an earlier run created whose source the symlinker no longer
# deploys: the file was deleted or renamed, the package was removed, or the
# package moved to Nix. Run before home-manager activates, so it finds those
# paths free instead of backing up a stale link. Only removes a symlink that
# points into the repo; real files and foreign links are left alone.
# Usage: prune_stale_package_links <packages_dir>
prune_stale_package_links() {
    local packages_dir="${1%/}"
    local manifest pkg_name deployed rel target
    for manifest in "$(package_manifest_dir)"/symlinks-*.txt; do
        [[ -f "$manifest" ]] || continue
        pkg_name="$(basename "$manifest" .txt)"
        pkg_name="${pkg_name#symlinks-}"
        deployed=1
        if [[ ! -d "$packages_dir/$pkg_name" ]] || is_nix_owned_package "$pkg_name"; then
            deployed=0
        fi
        while IFS= read -r rel; do
            [[ -n "$rel" ]] || continue
            target="$HOME/$rel"
            [[ -L "$target" && "$(readlink "$target")" == "$DOTFILES_DIR"/* ]] || continue
            if ((!deployed)) || [[ ! -e "$packages_dir/$pkg_name/$rel" ]]; then
                rm -f "$target"
                echo "  - $target (no longer deployed)"
            fi
        done <"$manifest"
        ((deployed)) || rm -f "$manifest"
    done
}

# Symlink all packages in a directory
# Usage: symlink_all_packages <packages_dir>
symlink_all_packages() {
    local packages_dir="$1"

    for pkg in "$packages_dir"/*/; do
        [[ -d "$pkg" ]] || continue

        local pkg_name
        pkg_name="$(basename "$pkg")"
        if is_nix_owned_package "$pkg_name"; then
            echo "[$pkg_name] managed by home-manager — skipping symlink"
            continue
        fi

        symlink_package "$pkg"
    done
}
