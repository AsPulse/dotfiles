{
  config,
  lib,
  pkgs,
  ...
}:
{
  # texmf の配置も一緒に止める。TeX 本体が無いホストに置いても読む側がいない。
  config = lib.mkIf config.aspulse.profiles.workstation.enable {
    home.packages = [
      pkgs.texliveFull
    ];

    home.file."texmf/tex/latex" = {
      source = ../latex;
      recursive = true;
    };
  };
}
