# Shell configuration shared by zsh and bash: aliases, PATH, session variables,
# and the bash rc itself. zsh-only setup is in zsh.nix. The prompt, history
# search, directory jumping, and per-directory env come from the starship,
# atuin, fzf, zoxide, and direnv modules, which hook into every enabled shell.
{ config, ... }:
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
    # mise shims: version-stable fallback for non-interactive shells and hooks;
    # `mise activate` prepends real tool paths in interactive shells anyway.
    "${config.home.homeDirectory}/.local/share/mise/shims"
  ];

  home.shellAliases = {
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

    # Kagi settings as code (tools/kagi); needs KAGI_SESSION_LINK in ~/.secrets
    kagi = "uv run --project \"$HOME/.dotfiles/tools/kagi\" kagi";

    # AI agents
    cc = "claude";
    cx = "codex";

    # Dev / network / misc
    nr = "npm run";
    ts = "tailscale";
    c = "clear";
    h = "history";
    grep = "grep --color=auto";
    df = "df -h";
    du = "du -h";
  };

  programs.bash = {
    enable = true;
    historySize = 10000;
    historyFileSize = 20000;
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];

    # ~/.profile (login shell): the omakase MOTD, as in zsh's profileExtra.
    profileExtra = ''
      [[ -x "$HOME/.dotfiles/bin/omakase-motd" ]] && "$HOME/.dotfiles/bin/omakase-motd"
    '';

    # Interactive shells only (home-manager guards ~/.bashrc itself).
    initExtra = ''
      command -v mise &>/dev/null && eval "$(mise activate bash)"

      # Shared shell functions, baked from packages/shell/.functions.
      ${builtins.readFile ../../../packages/shell/.functions}

      # Secrets (API keys, tokens — not tracked in dotfiles)
      [[ -f ~/.secrets ]] && source ~/.secrets

      # `if` rather than `&&`: as the last command of the rc, a short-circuited
      # && would make every `bash -i -c cmd` report failure when the file is
      # absent.
      if [[ -f "$HOME/.posthog/env" ]]; then . "$HOME/.posthog/env"; fi
    '';
  };
}
