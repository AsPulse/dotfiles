{ pkgs, lib, ... }:
let
  substituteScript =
    src:
    lib.replaceStrings
      [
        "@rsync@"
        "@ssh@"
      ]
      [
        "${pkgs.rsync}/bin/rsync"
        "${pkgs.openssh}/bin/ssh"
      ]
      (builtins.readFile src);
  openMacbook = pkgs.writeShellScriptBin "OpenMacbook" (substituteScript ../scripts/open-macbook.sh);
  returnMacbook = pkgs.writeShellScriptBin "ReturnMacbook" (
    substituteScript ../scripts/return-macbook.sh
  );
in
{
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    openMacbook
    returnMacbook
    pkgs.rsync
    pkgs.openssh
  ];
}
