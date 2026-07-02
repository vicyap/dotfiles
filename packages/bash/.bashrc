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

# PATH (kept in step with zsh's home.sessionPath in nix/home/features/zsh.nix)
export PATH="$HOME/.dotfiles/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.resend/bin:$PATH"

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

# `if` rather than `&&`: as the last line of the file, a short-circuited &&
# would leave the whole rc with exit status 1 when the file is absent, so
# every `bash -i -c cmd` reports spurious failure.
if [[ -f "$HOME/.posthog/env" ]]; then . "$HOME/.posthog/env"; fi
