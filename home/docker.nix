{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals config.aspulse.profiles.workstation.enable (
    (with pkgs; [
      docker
      docker-compose
    ])
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.colima
    ]
  );
}
