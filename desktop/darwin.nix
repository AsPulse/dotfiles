{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    xcbuild
    libiconv
  ];

  nix.enable = true;

  environment.variables.LIBRARY_PATH = "${lib.makeLibraryPath [ pkgs.libiconv ]}:$LIBRARY_PATH";

  security.pam.services.sudo_local.touchIdAuth = true;

  system.startup.chime = false;
}
