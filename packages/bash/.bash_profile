# ~/.bash_profile - Login shell configuration

# Source .bashrc if it exists (which sources ~/.posthog/env, guarded)
[[ -f ~/.bashrc ]] && source ~/.bashrc

# Omakase tool reminder (login-shell only).
[[ -x "$HOME/.dotfiles/bin/omakase-motd" ]] && "$HOME/.dotfiles/bin/omakase-motd"
