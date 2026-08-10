{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    xcbuild
  ];

  nix.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  system.startup.chime = false;
}
