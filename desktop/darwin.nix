{ ... }:
{
  nix.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  system.startup.chime = false;
}
