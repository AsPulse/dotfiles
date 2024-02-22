{  pkgs, ... }: {
  programs.neovim = {
    enable = true;
    withNodeJs = true;
  };
  home.file.".config/nvim" = {
    source = ./config;
    recursive = false;
  };
  home.packages = with pkgs; [
    nodePackages.typescript-language-server
  ];
}
