{ pkgs, ... }:
{
  home.file.".skk/SKK-JISYO.L".source = "${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L";
  home.file.".skk/kana-rule.conf".source = ../ime/kana-rule.conf;
}
