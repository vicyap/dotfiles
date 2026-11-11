# zsh — native home-manager module. home-manager owns the generated ~/.zshrc and
# ~/.zprofile. Plugins use home-manager's blessed path (autosuggestion +
# syntax-highlighting, plus fzf-tab); the deliberate ordering of the old hand-
# written rc is preserved with mkBefore/mkAfter blocks.
#
# Aliases, PATH, and session variables are shared with bash and live in
# shell.nix. The shell functions stay as readable shell in
# packages/shell/.functions, and the two zsh-only helpers (theme.zsh,
# alias-suggest.zsh) in packages/zsh; they are baked into the generated rc via
# readFile, so editing them takes effect on the next home-manager switch.
{
  config,
  lib,
  pkgs,
  ...
}:
{
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

    # Mtime-gated compinit: reuse the dump with -C (skipping the ~23ms compaudit
    # fpath walk) unless the dump is missing or older than a day. The (#q)
    # qualifier needs extended_glob, which is not set globally — hence the
    # anonymous function with local_options. `touch` keeps the daily clock
    # honest even when compinit leaves an unchanged dump untouched.
    completionInit = ''
      autoload -U compinit
      () {
        setopt local_options extended_glob
        local zcd=''${ZDOTDIR:-$HOME}/.zcompdump
        if [[ -n $zcd(#qN.mh-24) ]]; then
          compinit -C
        else
          compinit
          touch "$zcd"
        fi
        # Byte-compile the dump when it is newer than its .zwc (zsh prefers a
        # fresher name.zwc when sourcing). Compile to a temp name and mv so
        # concurrently starting shells never read a half-written file.
        if [[ -s $zcd && (! -s $zcd.zwc || $zcd -nt $zcd.zwc) ]]; then
          local tmp=$zcd.$$
          if zcompile "$tmp" "$zcd" 2>/dev/null; then
            mv -f "$tmp.zwc" "$zcd.zwc"
          else
            rm -f "$tmp.zwc"
          fi
        fi
      }
    '';

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

    # ~/.zshenv: Ubuntu's /etc/zsh/zshrc runs its own full compinit unless this
    # is set, doubling completion init for every /usr/bin/zsh start (the login
    # shell SSH and tmux actually spawn) — measured at ~580ms per shell on
    # an Ubuntu host. Inert on macOS, whose /etc/zshrc has no such gate.
    envExtra = ''
      skip_global_compinit=1
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

        # `if` rather than `&&`: near the end of the rc, a short-circuited &&
        # would leave a fresh shell with exit status 1 when the file is absent.
        if [[ -f "$HOME/.posthog/env" ]]; then . "$HOME/.posthog/env"; fi

        # Open URLs on local browser from headless remotes (ssh-opener).
        # Inner `if` rather than `&&`: this is the last command of the rc, so a
        # missing ssh-opener would otherwise start every shell with $? = 1.
        if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" && "$(uname)" != "Darwin" ]]; then
          if command -v ssh-opener &>/dev/null; then export BROWSER="ssh-opener"; fi
        fi
      '')
    ];
  };
}
