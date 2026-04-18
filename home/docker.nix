{ lib, pkgs, ... }:
{
  home.packages =
    (with pkgs; [
      docker
      docker-compose
    ])
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.colima
    ];
}
