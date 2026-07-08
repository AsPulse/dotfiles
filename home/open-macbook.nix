{ pkgs, lib, ... }:
let
  scriptText = lib.replaceStrings
    [
      "@rsync@"
      "@ssh@"
    ]
    [
      "${pkgs.rsync}/bin/rsync"
      "${pkgs.openssh}/bin/ssh"
    ]
    (builtins.readFile ../scripts/open-macbook.sh);
  openMacbook = pkgs.writeShellScriptBin "OpenMacbook" scriptText;
in
{
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    openMacbook
    pkgs.rsync
    pkgs.openssh
  ];
}
