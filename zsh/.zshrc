export TERM="xterm-256color"

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# ZSH_THEME="robbyrussell"
ZSH_THEME=""

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=~/.zsh/custom

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(autoenv command-not-found cp git git-prompt mercurial virtualenvwrapper)

source $ZSH/oh-my-zsh.sh
source $ZSH_CUSTOM/zsh-vcs-prompt/zshrc.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Aliases

alias tasks="task list"

# Theme

PROMPT_ICON=">"

# mercurial
ZSH_THEME_HG_PROMPT_PREFIX="%{$fg_bold[magenta]%}hg:(%{$fg[red]%}"
ZSH_THEME_HG_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_HG_PROMPT_DIRTY="%{$reset_color%}|%{$fg[yellow]%}✗%{$reset_color%}%{$fg[magenta]%})"
ZSH_THEME_HG_PROMPT_CLEAN="%{$reset_color%}|%{$fg[yellow]%}✔%{$reset_color%}%{$fg[magenta]%})"

# git
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[magenta]%}git:(%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[magenta]%})%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg_bold[red]%}"

# zsh_vcs_prompt
ZSH_VCS_PROMPT_ENABLE_CACHING='true'

#s : The VCS name (e.g. git svn hg).
#a : The action name (e.g. merge, rebase, rebase_i)
#b : The current branch name.

#c : The ahead status.
#d : The behind status.

#e : The staged status.
#f : The conflicted status.
#g : The unstaged status.
#h : The untracked status.
#i : The stashed status.
#j : The clean status.

## Git without Action.
# VCS name
ZSH_VCS_PROMPT_GIT_FORMATS='%{%B%F{magenta}%}#s%{%f%b%}'
# Branch name
ZSH_VCS_PROMPT_GIT_FORMATS+='%{%B%F{magenta}%}(%{%B%F{red}%}#b%{%f%b%}'
# Ahead and Behind
ZSH_VCS_PROMPT_GIT_FORMATS+='#c#d|'
# Staged
ZSH_VCS_PROMPT_GIT_FORMATS+='%{%F{blue}%}#e%{%f%b%}'
# Conflicts
ZSH_VCS_PROMPT_GIT_FORMATS+='%{%F{red}%}#f%{%f%b%}'
# Unstaged
ZSH_VCS_PROMPT_GIT_FORMATS+='%{%F{yellow}%}#g%{%f%b%}'
# Untracked
ZSH_VCS_PROMPT_GIT_FORMATS+='#h'
# Stashed
ZSH_VCS_PROMPT_GIT_FORMATS+='%{%F{cyan}%}#i%{%f%b%}'
# Clean
ZSH_VCS_PROMPT_GIT_FORMATS+='%{%F{green}%}#j%{%f%b%}%{%B%F{magenta}%})'

### Git with Action.
# VCS name
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS='%{%B%F{yellow}%}#s%{%f%b%}'
# Branch name
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='%{%B%F{magenta}%}(%{%B%F{red}%}#b%{%f%b%}'
# Action
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+=':%{%B%F{red}%}#a%{%f%b%}'
# Ahead and Behind
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='#c#d|'
# Staged
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='%{%F{blue}%}#e%{%f%}'
# Conflicts
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='%{%F{red}%}#f%{%f%}'
# Unstaged
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='%{%F{yellow}%}#g%{%f%}'
# Untracked
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='#h'
# Stashed
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='%{%F{cyan}%}#i%{%f%}'
# Clean
ZSH_VCS_PROMPT_GIT_ACTION_FORMATS+='%{%F{green}%}#j%{%f%}%{%B%F{magenta}%})'

## Other VCS without Action.
# VCS name
ZSH_VCS_PROMPT_VCS_FORMATS=''

## Other VCS with Action.
# VCS name
ZSH_VCS_PROMPT_VCS_ACTION_FORMATS=''

# Displays the exec time of the last command if set threshold was exceeded
#
cmd_exec_time() {
    local stop=`date +%s`
    local start=${cmd_timestamp:-$stop}
    let local elapsed=$stop-$start
    [ $elapsed -gt 5 ] && echo "%{$fg[yellow]%}${elapsed}s%{$reset_color%}"
}

# Get the initial timestamp for cmd_exec_time
#
function preexec() {
  cmd_timestamp=`date +%s`
}

local ret_status="%(?:%{$fg_bold[green]%}$PROMPT_ICON:%{$fg_bold[red]%}$PROMPT_ICON)"
PROMPT=$'\n%{$fg[cyan]%}$(pwd) $(git_super_status)$(hg_prompt_info) $(cmd_exec_time)\n%* ${ret_status} %{$reset_color%}'
RPROMPT=''

local ret_status="%(?:%{$fg_bold[green]%}$PROMPT_ICON:%{$fg_bold[red]%}$PROMPT_ICON)"
local current_user="%{$fg_bold[magenta]%}$(hostname)(%{$fg_bold[red]%}$(whoami)%{$fg_bold[magenta]%})"
local current_time="%{$reset_color%}%*"
PROMPT=$'\n%{$fg[cyan]%}$(pwd) $(vcs_super_info)$(hg_prompt_info) $(cmd_exec_time)\n${current_time} ${current_user} ${ret_status} %{$reset_color%}'
RPROMPT=''

# virtualenvwrapper

export WORKON_HOME=~/.virtualenvs
DISABLE_VENV_CD=0
VIRTUAL_ENV_DISABLE_PROMPT=1
