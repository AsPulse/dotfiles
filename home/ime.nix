{
  config,
  lib,
  pkgs,
  ...
}:
let
  macSkkSettingsDir = "${config.home.homeDirectory}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings";
in
{
  # macSKKがnix storeにある設定ファイルを読もうとしてもTCCでブロックされてしまうため、
  # 直接配置する。
  home.activation.installMacSkkKanaRule = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      mkdir -p ${lib.escapeShellArg macSkkSettingsDir}

      install -m 0644 ${lib.escapeShellArg (toString ../ime/kana-rule.conf)} \
        ${lib.escapeShellArg "${macSkkSettingsDir}/kana-rule.conf"}
    ''
  );
}
