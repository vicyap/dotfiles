# ~/.bashrc - Bash configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Source shared aliases and functions
[[ -f ~/.aliases ]] && source ~/.aliases
[[ -f ~/.functions ]] && source ~/.functions

# PATH
export PATH="$HOME/.dotfiles/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# mise
command -v mise &>/dev/null && eval "$(mise activate bash)"

# starship prompt (parity with the zsh config; falls back to PS1 above if absent)
command -v starship &>/dev/null && eval "$(starship init bash)"

# zoxide (z / zi directory jumping)
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# direnv (per-directory env loading)
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# atuin owns Ctrl+R; --disable-up-arrow keeps default history search on UP
command -v atuin &>/dev/null && eval "$(atuin init bash --disable-up-arrow)"

# Secrets
[[ -f ~/.secrets ]] && source ~/.secrets

[[ -f "$HOME/.posthog/env" ]] && . "$HOME/.posthog/env"
