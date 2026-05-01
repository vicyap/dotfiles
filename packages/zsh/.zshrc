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

# Pass unmatched globs through literally instead of erroring.
# Prevents zsh from choking on paths with parentheses like app/(tabs)/
setopt NO_NOMATCH
setopt INTERACTIVE_COMMENTS

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Key bindings (emacs style)
bindkey -e

# Environment
export EDITOR=vim
export VISUAL=vim
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# PATH
export PATH="$HOME/.dotfiles/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Wrap dotfiles CLI so `dotfiles cd` can change the shell's directory
dotfiles() {
  if [[ "$1" == "cd" ]]; then
    cd "$HOME/.dotfiles"
  else
    command dotfiles "$@"
  fi
}

# Aliases and functions
[[ -f ~/.aliases ]] && source ~/.aliases
[[ -f ~/.functions ]] && source ~/.functions
[[ -f ~/.zsh/alias-suggest.zsh ]] && source ~/.zsh/alias-suggest.zsh
[[ -f ~/.zsh/theme.zsh ]] && source ~/.zsh/theme.zsh

# mise (manages Go, Node, Python, Bun)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# Tool integrations
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"
# atuin owns Ctrl+R; --disable-up-arrow keeps history-search-backward on UP
command -v atuin &>/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# fzf
[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh

# Prefix history search (after fzf so these aren't overridden)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[OA' history-search-backward
bindkey '^[OB' history-search-forward

# Zsh trio: fzf-tab (after compinit), then highlighting, then autosuggestions
[[ -f $HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]] \
  && source $HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
[[ -f $HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] \
  && source $HOME/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
[[ -f $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# fzf-tab Catppuccin Mocha colors + cd preview
zstyle ':fzf-tab:*' fzf-flags --color=fg:-1,bg:-1,hl:#f5c2e7,fg+:-1,bg+:#313244,hl+:#f5c2e7
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'

# uv
[[ -s "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# Secrets (API keys, tokens - not tracked in dotfiles)
[[ -f ~/.secrets ]] && source ~/.secrets

# Open URLs on local machine's browser from headless remotes (github.com/vicyap/ssh-opener)
if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" && "$(uname)" != "Darwin" ]]; then
  command -v ssh-opener &>/dev/null && export BROWSER="ssh-opener"
fi

[[ -f "$HOME/.posthog/env" ]] && . "$HOME/.posthog/env"

# Resend CLI
export PATH="$HOME/.resend/bin:$PATH"
