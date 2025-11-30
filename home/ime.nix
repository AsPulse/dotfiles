{ lib, pkgs, ... }: {
  home.file."Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings/kana-rule.conf" =
    lib.mkIf pkgs.stdenv.isDarwin {
      source = ../ime/kana-rule.conf;
    };
}
