# starship — native home-manager module. The 206-line hand-tuned prompt config
# is read from the repo TOML and re-serialized by home-manager, so the prompt
# stays declarative without hand-translating every bracketed format string.
{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (
      builtins.readFile ../../../packages/starship/.config/starship.toml
    );
  };
}
