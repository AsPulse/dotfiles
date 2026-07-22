{ pkgs, ... }:
let
  onishi = import ../ime/onishi.nix { inherit pkgs; };
in
{
  home.file.".skk/SKK-JISYO.L".source = "${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L";
  home.file.".skk/kana-rule-onishi.json".source = onishi.skkeletonJson;
}
