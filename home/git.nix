{ lib, pkgs, ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      commit.gpgsign = true;
      core.excludesfile = "~/.gitignore_global";
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        line-numbers = true;
      };
      merge.conflictStyle = "zdiff3";
    };
  };

  home.file.".gitignore_global" = {
    source = ./git/.gitignore_global;
  };

  # GitHub

  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-markdown-preview
      gh-dash
      gh-poi
    ];

    settings = {
      editor = "nvim";
    };
  };

  # Signed Commit

  programs.gpg.enable = true;

  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    pinentryFlavor = "curses";
  };

  home.file.".gnupg/gpg-agent.conf".text = lib.mkIf pkgs.stdenv.isDarwin ''
    pinentry-program ${(pkgs.callPackage ./pinentry-touchid { }).outPath}/bin/pinentry-touchid
  '';

  # lazygit

  home.file.".config/lazygit/config.yml" = lib.mkIf pkgs.stdenv.isLinux {
    source = ../lazygit/config.yml;
  };

  home.file."Library/Application Support/lazygit/config.yml" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../lazygit/config.yml;
  };

  home.packages = with pkgs; [
    lazygit
    (pkgs.callPackage ./pinentry-touchid { })
    pinentry_mac
    difftastic
    delta
  ];
}
