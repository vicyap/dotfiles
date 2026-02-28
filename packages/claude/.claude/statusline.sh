#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Base prompt with colors (green for user@host, blue for directory)
printf '%s\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' \
    "${debian_chroot:+($debian_chroot)}" \
    "$(whoami)" \
    "$(hostname -s)" \
    "$(pwd)"

# Git branch with dirty indicator (if in a git repo)
branch=$(git -c core.useBuiltinFSMonitor=false --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
    # Check for uncommitted changes (fast method)
    dirty=""
    if ! git -c core.useBuiltinFSMonitor=false --no-optional-locks diff --quiet HEAD 2>/dev/null; then
        dirty="●"
    elif [ -n "$(git -c core.useBuiltinFSMonitor=false --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
        dirty="+"
    fi
    printf ' [%s%s]' "$branch" "$dirty"
fi

# Model name from JSON input (cyan color)
model=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model" ]; then
    printf ' \033[01;36m[%s]\033[00m' "$model"
fi

# Context USED percentage from JSON input (magenta color)
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx" ]; then
    printf ' \033[01;35m[ctx %.0f%%]\033[00m' "$ctx"
fi

# --- Claude Code rate limit usage (managed by /setup-statusline) ---
usage_segment=$("$HOME/.claude/scripts/usage-segment.sh" 2>/dev/null)
if [ -n "$usage_segment" ]; then
    printf ' %s' "$usage_segment"
fi
# --- end rate limit usage ---
