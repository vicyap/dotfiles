# ~/.zprofile - Login shell configuration for zsh

# Homebrew (macOS)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Omakase tool reminder (login-shell only; not run per tmux pane).
[[ -x "$HOME/.dotfiles/bin/omakase-motd" ]] && "$HOME/.dotfiles/bin/omakase-motd"
