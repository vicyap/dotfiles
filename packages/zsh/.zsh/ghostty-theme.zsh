#!/usr/bin/env zsh
# Ghostty theme switching: `light` / `dark`
# Edits the config and sends SIGUSR2 to reload.

GHOSTTY_CONFIG="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" 2>/dev/null || echo "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config")"

_ghostty_set_theme() {
    local theme="$1"
    sed -i '' "s/^theme = .*/theme = ${theme}/" "$GHOSTTY_CONFIG"
    pkill -USR2 -x ghostty 2>/dev/null
    echo "Ghostty: ${theme}"
}

light() { _ghostty_set_theme "TokyoNight Day"; }
dark() { _ghostty_set_theme "TokyoNight Night"; }
