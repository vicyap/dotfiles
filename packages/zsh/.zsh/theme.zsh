# Theme switching: `light` / `dark` (sourced into the zsh rc; no shebang)
# Switches Ghostty, Claude Code, Tmux, and shell tool themes together.

GHOSTTY_CONFIG="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" 2>/dev/null || echo "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config")"

_apply_theme_env() {
    local mode="$1"
    export THEME_MODE="$mode"
    if [[ "$mode" == "light" ]]; then
        export BAT_THEME="GitHub"
        export FZF_DEFAULT_OPTS="--color=light"
        # delta: activate the light-mode feature defined in nix/home/features/git.nix
        export DELTA_FEATURES="+theme-light"
    else
        export BAT_THEME="Catppuccin Mocha"
        export FZF_DEFAULT_OPTS="--color=dark"
        unset DELTA_FEATURES
    fi
}

# Apply saved theme on shell startup
if [[ -f ~/.theme-mode ]]; then
    _apply_theme_env "$(< ~/.theme-mode)"
else
    _apply_theme_env dark
fi

_set_theme() {
    local mode="$1" ghostty_theme="$2"
    local switched=()

    # Persist mode for new shells
    echo "$mode" > ~/.theme-mode

    # Shell env (bat, fzf, delta, vim)
    _apply_theme_env "$mode"
    switched+=("bat, fzf, delta, vim")

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

    # Tmux: reload the active server even when invoked outside a tmux client.
    # This targets the default tmux server/socket, not custom `tmux -L` or `tmux -S` servers.
    if command -v tmux &>/dev/null; then
        local tmux_theme="$HOME/.tmux/themes/${mode}.conf"
        if [[ -f "$tmux_theme" ]] && tmux ls &>/dev/null; then
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
dark() { _set_theme dark "Catppuccin Mocha"; }
