{ config, lib, ... }:
{
  home.file.".config/opencode/tui.json" = lib.mkIf config.aspulse.profiles.agents.enable {
    source = ../opencode/tui.json;
  };
}
