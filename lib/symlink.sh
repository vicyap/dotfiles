#!/usr/bin/env bash
# Symlink helper functions

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# Force overwrite existing files without prompting
# DOTFILES_FORCE: set to 1 to back up and replace all conflicts
is_force() {
  [[ "$DOTFILES_FORCE" == "1" ]]
}

# Detect if running interactively
# DOTFILES_INTERACTIVE: auto (default), always, never
is_interactive() {
  if [[ "$DOTFILES_INTERACTIVE" == "always" ]]; then
    return 0
  elif [[ "$DOTFILES_INTERACTIVE" == "never" ]]; then
    return 1
  else
    [[ -t 0 ]]  # auto: check if stdin is a terminal
  fi
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

  if [[ ! -d "$pkg_path" ]]; then
    echo "Package not found: $pkg_path"
    return 1
  fi

  echo "[$pkg_name]"

  # Find all files (not directories) and symlink them
  while IFS= read -r -d '' file; do
    local rel_path="${file#$pkg_path/}"
    local target="$HOME/$rel_path"
    create_symlink "$file" "$target"
  done < <(find "$pkg_path" -type f -print0)
}

# Symlink all packages in a directory
# Usage: symlink_all_packages <packages_dir>
symlink_all_packages() {
  local packages_dir="$1"

  for pkg in "$packages_dir"/*/; do
    [[ -d "$pkg" ]] && symlink_package "$pkg"
  done
}
