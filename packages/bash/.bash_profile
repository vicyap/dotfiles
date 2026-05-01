# ~/.bash_profile - Login shell configuration

# Source .bashrc if it exists
[[ -f ~/.bashrc ]] && source ~/.bashrc

. "$HOME/.posthog/env"

# Omakase tool reminder (login-shell only).
[[ -x "$HOME/.dotfiles/bin/omakase-motd" ]] && "$HOME/.dotfiles/bin/omakase-motd"
