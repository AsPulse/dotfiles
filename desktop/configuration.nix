{ lib, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    btop
    unzip
    nix-prefetch-github
    pkg-config
    s3fs
    xcbuild
    openssl.dev
    libiconv
    evcxr
    rclone
  ];

  nix.enable = true;

  environment.variables.LIBRARY_PATH = "${builtins.trace (lib.makeLibraryPath [ pkgs.libiconv ]) (lib.makeLibraryPath [ pkgs.libiconv ])}:$LIBRARY_PATH";

  security.pam.services.sudo_local.touchIdAuth = lib.mkIf pkgs.stdenv.isDarwin true;

  system = lib.mkIf pkgs.stdenv.isDarwin {
    startup.chime = false;
  };

  imports = [ ];

  # Auto upgrade nix package and the daemon service.
  # services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  nix.settings = {
    experimental-features = "nix-command flakes";
  };

  programs.zsh.enable = true;

}
