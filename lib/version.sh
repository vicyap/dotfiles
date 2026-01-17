#!/usr/bin/env bash
# Version management utilities

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Get desired version from versions.conf
# Usage: get_desired_version <tool>
get_desired_version() {
  local tool="$1"
  grep "^${tool}=" "$DOTFILES_DIR/versions.conf" 2>/dev/null | cut -d= -f2
}

# Get currently installed version
# Usage: get_installed_version <tool>
get_installed_version() {
  local tool="$1"
  case "$tool" in
    go)
      go version 2>/dev/null | awk '{print $3}' | sed 's/go//'
      ;;
    web)
      if command -v web &>/dev/null; then
        web --version 2>/dev/null || echo "installed"
      else
        echo "none"
      fi
      ;;
    ask)
      if command -v ask &>/dev/null; then
        echo "installed"
      else
        echo "none"
      fi
      ;;
    *)
      echo "none"
      ;;
  esac
}

# Check if a tool needs to be updated
# Returns 0 (true) if update needed, 1 (false) if not
# Usage: needs_update <tool>
needs_update() {
  local tool="$1"
  local desired installed

  desired="$(get_desired_version "$tool")"
  installed="$(get_installed_version "$tool")"

  # No desired version configured
  [[ -z "$desired" ]] && return 1

  # Always update for "latest"
  [[ "$desired" == "latest" ]] && return 0

  # Not installed
  [[ "$installed" == "none" ]] && return 0

  # Version mismatch
  [[ "$installed" != "$desired" ]]
}
