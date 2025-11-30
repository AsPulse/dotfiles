{ pkgs, ... }:
{
  home.file.".config/nvim" = {
    source = ../neovim;
    recursive = false;
  };
  home.file.".vim/tsnip" = {
    source = ../tsnip;
    recursive = false;
  };

  home.packages =
    with pkgs;
    [
      neovim
      lua5_1
      luarocks
      clang
      cmake
      lua-language-server
      editorconfig-checker
      tree-sitter
      tailwindcss-language-server
      dockerfile-language-server
      vscode-langservers-extracted
      yaml-language-server
      nixd
      texlab
      pyright
      sshfs
      tombi
    ]
    ++ (with pkgs.nodePackages; [
      typescript-language-server
      bash-language-server
    ]);
}
