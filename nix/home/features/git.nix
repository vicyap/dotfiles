# git — native home-manager module; all git config lives in the `settings`
# attrset below (replaced the old packages/git/.gitconfig).
{ pkgs, ... }:
{
  # delta is its own module in home-manager 26.05. enableGitIntegration wires
  # core.pager and interactive.diffFilter into git.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;

    # Raw git config (the `settings` attrset mirrors git config sections).
    settings = {
      user = {
        name = "Victor Yap";
        email = "vicyap@users.noreply.github.com";
      };

      init.defaultBranch = "main";
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      pull.ff = "only";
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      color.ui = "auto";

      alias.initer =
        "!f() { git init && git commit --allow-empty --allow-empty-message --message ''; }; f";

      # gh as the credential helper. The empty first value resets any inherited
      # helper before ours, matching the original .gitconfig. Referencing the
      # Nix-provided gh keeps the path correct on both Linux and macOS.
      credential."https://github.com".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];
      credential."https://gist.github.com".helper = [
        ""
        "!${pkgs.gh}/bin/gh auth git-credential"
      ];

      # Normalize the live ghostty theme line back to the committed default.
      filter.ghostty-theme = {
        clean = "sed 's/^theme = .*/theme = Catppuccin Mocha/'";
        smudge = "cat";
      };
    };
  };
}
