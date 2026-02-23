# ~/.zshrc

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=20000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_SILENT

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Key bindings (emacs style)
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Environment
export EDITOR=vim
export VISUAL=vim
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TERM=xterm-256color

# PATH
export PATH="$HOME/.dotfiles/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Aliases
[[ -f ~/.aliases ]] && source ~/.aliases
[[ -f ~/.zsh/alias-suggest.zsh ]] && source ~/.zsh/alias-suggest.zsh

# mise (manages Go, Node, Python, Bun)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# Tool integrations
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# fzf
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh

# uv
[[ -s "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# Secrets (API keys, tokens - not tracked in dotfiles)
[[ -f ~/.secrets ]] && source ~/.secrets
