# zsh — native home-manager module. home-manager owns the generated ~/.zshrc and
# ~/.zprofile. Plugins use home-manager's blessed path (autosuggestion +
# syntax-highlighting, plus fzf-tab); the deliberate ordering of the old hand-
# written rc is preserved with mkBefore/mkAfter blocks.
#
# Simple aliases live in shellAliases (declarative). The complex shell functions
# stay as readable shell in packages/shell/.functions and the two zsh-only
# helpers (theme.zsh, alias-suggest.zsh); they are baked into the generated rc
# via readFile, so the repo files remain the editable source and bash keeps
# sourcing them via its own symlinks.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.dotfiles/bin"
    "${config.home.homeDirectory}/go/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/bin"
    "${config.home.homeDirectory}/.resend/bin"
  ];

  programs.zsh = {
    enable = true;
    autocd = true;
    defaultKeymap = "emacs";

    history = {
      size = 10000;
      save = 20000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    plugins = [
      {
        name = "fzf-tab";
        # Ship fzf-tab WITHOUT its precompiled native module. The module is built
        # against the Nix zsh + glibc, so loading it from a system zsh (e.g.
        # tmux's default shell on Linux) fails and, interactively, hangs on a
        # "rebuild now?" prompt. With no module present, fzf-tab falls back to its
        # pure-zsh implementation on every shell, Linux and macOS alike.
        src = pkgs.runCommand "fzf-tab-no-module" { } ''
          cp -r ${pkgs.zsh-fzf-tab}/share/fzf-tab $out
          chmod -R u+w $out
          rm -rf $out/modules
        '';
        file = "fzf-tab.plugin.zsh";
      }
    ];

    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # ls (eza) — the flag-translating `ls` wrapper is a function in .functions
      ll = "eza -la --git --icons --group-directories-first";
      la = "eza -a --icons";
      l = "eza -F --icons";
      ltree = "eza --tree --level=2 --icons";

      # Git
      g = "git";
      ga = "git add";
      gaa = "git add --all";
      gb = "git branch";
      gba = "git branch -a";
      gc = "git commit";
      gcmsg = "git commit -m";
      gco = "git checkout";
      gcb = "git checkout -b";
      gcl = "git clone";
      gcp = "git cherry-pick";
      gd = "git diff";
      gds = "git diff --staged";
      gf = "git fetch";
      gl = "git pull";
      glg = "git log --graph --decorate --stat --color";
      glog = "git log --oneline --graph --decorate";
      gm = "git merge";
      gp = "git push";
      gpom = "git pull origin main";
      ggpush = "git push origin $(git branch --show-current)";
      ggpull = "git pull origin $(git branch --show-current)";
      grb = "git rebase";
      grh = "git reset HEAD";
      gst = "git status";
      gsta = "git stash";
      gstp = "git stash pop";

      # TUIs
      lg = "lazygit";
      lzd = "lazydocker";

      # Cheatsheet
      oma = "glow ~/.dotfiles/CHEATSHEET.md";

      # AI agents
      cc = "claude";
      cx = "codex";
      oc = "opencode";

      # Dev / network / misc
      nr = "npm run";
      ts = "tailscale";
      c = "clear";
      h = "history";
      grep = "grep --color=auto";
      df = "df -h";
      du = "du -h";
    };

    # ~/.zprofile (login shell): Homebrew shellenv + the omakase MOTD.
    profileExtra = ''
      # Homebrew (macOS)
      if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      # Omakase tool reminder (login-shell only; not run per tmux pane).
      [[ -x "$HOME/.dotfiles/bin/omakase-motd" ]] && "$HOME/.dotfiles/bin/omakase-motd"
    '';

    initContent = lib.mkMerge [
      # --- early: before compinit / plugins -------------------------------
      (lib.mkBefore ''
        # Extra options (AUTO_CD + history come from the module options above)
        setopt AUTO_PUSHD PUSHD_SILENT NO_NOMATCH INTERACTIVE_COMMENTS

        # Wrap dotfiles CLI so `dotfiles cd` changes the shell's directory
        dotfiles() {
          if [[ "$1" == "cd" ]]; then
            cd "$HOME/.dotfiles"
          else
            command dotfiles "$@"
          fi
        }

        # mise (language runtimes) — before compinit so completions register
        command -v mise &>/dev/null && eval "$(mise activate zsh)"

        # Shared shell functions (compress, image/video, ssh forwards, try, the
        # eza `ls` wrapper, ccc, ff) — baked from packages/shell/.functions.
        ${builtins.readFile ../../../packages/shell/.functions}
      '')

      # --- late: after compinit, plugins, and tool integrations -----------
      (lib.mkAfter ''
        # Theme switcher (light/dark) + startup theme env from ~/.theme-mode.
        # After fzf integration so the FZF_DEFAULT_OPTS set here wins.
        ${builtins.readFile ../../../packages/zsh/.zsh/theme.zsh}

        # fzf-tab styling (Catppuccin Mocha; not theme-switched) + cd preview
        zstyle ':fzf-tab:*' fzf-flags --color=fg:-1,bg:-1,hl:#f5c2e7,fg+:-1,bg+:#313244,hl+:#f5c2e7
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'

        # Completion menu styling
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

        # Prefix history search on UP/DOWN; atuin owns Ctrl-R; fzf-tab owns Tab.
        # Asserted last: programs.fzf's completion binds Tab to fzf-completion
        # after fzf-tab loads, so re-point Tab back at fzf-tab here (matching the
        # old rc, which sourced fzf-tab last). atuin likewise re-claims Ctrl-R.
        bindkey '^[[A' history-search-backward
        bindkey '^[[B' history-search-forward
        bindkey '^[OA' history-search-backward
        bindkey '^[OB' history-search-forward
        bindkey '^R' atuin-search
        bindkey '^I' fzf-tab-complete

        # Alias suggestions (preexec hook) — last, so the table sees every alias.
        # Guarded: the inlined file's top-level `return` (for ALIAS_SUGGEST_DISABLE)
        # would otherwise abort the rest of this rc (secrets, BROWSER, etc.).
        if [[ -z "$ALIAS_SUGGEST_DISABLE" ]]; then
          ${builtins.readFile ../../../packages/zsh/.zsh/alias-suggest.zsh}
        fi

        # uv shims
        [[ -s "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

        # Secrets (API keys, tokens — not tracked in dotfiles)
        [[ -f ~/.secrets ]] && source ~/.secrets

        [[ -f "$HOME/.posthog/env" ]] && . "$HOME/.posthog/env"

        # Open URLs on local browser from headless remotes (ssh-opener)
        if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" && "$(uname)" != "Darwin" ]]; then
          command -v ssh-opener &>/dev/null && export BROWSER="ssh-opener"
        fi
      '')
    ];
  };
}
