{ lib, pkgs, ... }:
{
  # Blender 本体を動かすのは NixOS マシンだけなので、Darwin に Blender の closure を
  # 引き込まないよう Linux に限定する。
  config = lib.mkIf pkgs.stdenv.isLinux {
    aspulse.mcpServers.blender = {
      type = "stdio";
      command = lib.getExe (pkgs.callPackage ./blender-mcp { });
    };
  };
}
