#!/usr/bin/env zsh
# Theme switching: `light` / `dark`
# Switches Ghostty, Claude Code, and Tmux themes together.

GHOSTTY_CONFIG="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" 2>/dev/null || echo "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config")"

_set_theme() {
    local mode="$1" ghostty_theme="$2"
    local switched=()

    # Ghostty
    if [[ -f "$GHOSTTY_CONFIG" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s/^theme = .*/theme = ${ghostty_theme}/" "$GHOSTTY_CONFIG"
            osascript -e 'tell application "System Events" to tell process "ghostty" to click menu item "Reload Configuration" of menu "Ghostty" of menu bar 1' &>/dev/null
        else
            sed -i "s/^theme = .*/theme = ${ghostty_theme}/" "$GHOSTTY_CONFIG"
        fi
        switched+=("Ghostty: ${ghostty_theme}")
    fi

    # Claude Code
    if [[ -f ~/.claude.json ]] && command -v jq &>/dev/null; then
        jq --arg t "$mode" '.theme = $t' ~/.claude.json > ~/.claude.json.tmp && mv -f ~/.claude.json.tmp ~/.claude.json
        switched+=("Claude Code: ${mode}")
    fi

    # Tmux
    if command -v tmux &>/dev/null && [[ -n "$TMUX" ]]; then
        local tmux_theme="$HOME/.tmux/themes/tokyonight-${mode}.conf"
        if [[ -f "$tmux_theme" ]]; then
            tmux source-file "$tmux_theme"
            switched+=("Tmux: ${mode}")
        fi
    fi

    if (( ${#switched[@]} )); then
        echo "Switched to ${mode} mode (${(j:, :)switched})"
    else
        echo "Switched to ${mode} mode (no apps to update)"
    fi
}

light() { _set_theme light "GitHub Light High Contrast"; }
dark() { _set_theme dark "TokyoNight Night"; }
