#!/usr/bin/env zsh
# Ghostty theme switching: `light` / `dark`
# Edits the config and triggers reload via macOS menu action.

GHOSTTY_CONFIG="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" 2>/dev/null || echo "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config")"

_ghostty_set_theme() {
    local theme="$1"
    sed -i '' "s/^theme = .*/theme = ${theme}/" "$GHOSTTY_CONFIG"
    osascript -e 'tell application "System Events" to tell process "ghostty" to click menu item "Reload Configuration" of menu "Ghostty" of menu bar 1' &>/dev/null
    echo "Ghostty: ${theme}"
}

light() { _ghostty_set_theme "TokyoNight Day"; }
dark() { _ghostty_set_theme "TokyoNight Night"; }
