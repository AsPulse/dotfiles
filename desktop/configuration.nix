{ lib, pkgs, ... }:
{
  imports =
    lib.optionals pkgs.stdenv.isDarwin [ ./darwin.nix ]
    ++ lib.optionals pkgs.stdenv.isLinux [ ./linux.nix ];

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
    openssl.dev
    evcxr
    rclone
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  programs.zsh.enable = true;
}
