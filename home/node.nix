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
      turbo
      nodejs_24
    ]
  );

  # devShell の pnpm も ~/.npmrc を読むので、nodejs を入れないホストにも置く。
  programs.npm = {
    enable = true;
    package = null;
    settings.registry = "https://npm.flatt.tech/";
  };
}
