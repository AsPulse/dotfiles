{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals config.aspulse.profiles.workstation.enable (
    with pkgs;
    [
      typst
    ]
  );
}
