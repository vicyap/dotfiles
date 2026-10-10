# Timed sleep prevention belongs only to lima.
{ pkgs, ... }:
let
  helper = pkgs.writeScript "keep-awake" (builtins.readFile ./keep-awake.sh);
in
{
  environment.etc."keep-awake/helper".source = helper;
  environment.etc."keep-awake/toggle.applescript".source = ./keep-awake.applescript;

  launchd.daemons.keep-awake = {
    command = "${helper} daemon";
    serviceConfig = {
      UserName = "victoryap";
      EnvironmentVariables = {
        HOME = "/Users/victoryap";
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 5;
      ExitTimeOut = 20;
      StandardOutPath = "/Users/victoryap/Library/Logs/keep-awake.log";
      StandardErrorPath = "/Users/victoryap/Library/Logs/keep-awake.log";
    };
  };
}
