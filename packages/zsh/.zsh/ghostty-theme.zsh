#!/usr/bin/env zsh
# Theme switching: `light` / `dark`
# Switches Ghostty theme and Claude Code theme together.

GHOSTTY_CONFIG="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" 2>/dev/null || echo "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config")"

_set_theme() {
    local mode="$1" ghostty_theme="$2"

    # Ghostty
    sed -i '' "s/^theme = .*/theme = ${ghostty_theme}/" "$GHOSTTY_CONFIG"
    osascript -e 'tell application "System Events" to tell process "ghostty" to click menu item "Reload Configuration" of menu "Ghostty" of menu bar 1' &>/dev/null

    # Claude Code
    if [[ -f ~/.claude.json ]] && command -v jq &>/dev/null; then
        jq --arg t "$mode" '.theme = $t' ~/.claude.json > ~/.claude.json.tmp && mv -f ~/.claude.json.tmp ~/.claude.json
    fi

    echo "Switched to ${mode} mode (Ghostty: ${ghostty_theme})"
}

light() { _set_theme light "TokyoNight Day"; }
dark() { _set_theme dark "TokyoNight Night"; }
