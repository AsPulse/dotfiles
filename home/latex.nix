{
  config,
  lib,
  pkgs,
  ...
}:
let
  tex = (
    pkgs.texlive.combine {
      inherit (pkgs.texlive)
        scheme-full
        dvisvgm
        dvipng # for preview and export as html
        wrapfig
        amsmath
        ulem
        hyperref
        capt-of
        pgfplots
        ;
      #(setq org-latex-compiler "lualatex")
      #(setq org-preview-latex-default-process 'dvisvgm)
    }
  );
in
{
  # texmf の配置も一緒に止める。TeX 本体が無いホストに置いても読む側がいない。
  config = lib.mkIf config.aspulse.profiles.workstation.enable {
    home.packages = [
      tex
    ];

    home.file."texmf/tex/latex" = {
      source = ../latex;
      recursive = true;
    };
  };
}
