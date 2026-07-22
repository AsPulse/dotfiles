{
  config,
  lib,
  pkgs,
  ...
}:
let
  macSkkSettingsDir = "${config.home.homeDirectory}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings";
  onishi = import ../ime/onishi.nix { inherit pkgs; };
in
{
  # macSKKがnix storeにある設定ファイルを読もうとしてもTCCでブロックされてしまうため、
  # 直接配置する。
  home.activation.configureMacSkk = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      mkdir -p ${lib.escapeShellArg macSkkSettingsDir}

      install -m 0644 ${lib.escapeShellArg (toString onishi.macskk)} \
        ${lib.escapeShellArg "${macSkkSettingsDir}/kana-rule.conf"}

      # キーバインドは UserDefaults 管理のため defaults write で宣言的に上書きする。
      # GUI での変更はリビルドで巻き戻る。反映には macSKK の再起動が必要
      # (入力メソッドは kill 後に自動で再起動される)。
      /usr/bin/defaults write net.mtgto.inputmethod.macSKK keyBindingSets \
        "$(cat ${lib.escapeShellArg (toString ../ime/macskk-keybindings.plist)})"
      /usr/bin/defaults write net.mtgto.inputmethod.macSKK selectedKeyBindingSetId \
        -string "macSKK *"
      /usr/bin/killall macSKK || true
    ''
  );
}
