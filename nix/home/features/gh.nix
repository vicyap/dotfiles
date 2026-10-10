# gh — GitHub CLI. gitCredentialHelper (on by default) generates the
# credential."https://github.com"/gist entries in git's config that git.nix
# used to hand-roll. Settings mirror the pre-migration ~/.config/gh/config.yml;
# hosts.yml (the OAuth token from `gh auth login`) stays runtime-owned.
{ ... }:
{
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
      aliases.co = "pr checkout";
    };
  };
}
