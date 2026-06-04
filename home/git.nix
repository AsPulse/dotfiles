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

  # macOS は Touch ID で署名 (pinentry-touchid は public flake ローカルのためここに置く)。
  # Linux 側の gpg 運用設定 (キャッシュ・pinentry・開錠ヘルパ) はマシン固有なので
  # private/home/gpg.nix に置く。
  home.file.".gnupg/gpg-agent.conf" = lib.mkIf pkgs.stdenv.isDarwin {
    text = ''
      pinentry-program ${(pkgs.callPackage ./pinentry-touchid { }).outPath}/bin/pinentry-touchid
    '';
  };

  # lazygit

  home.file.".config/lazygit/config.yml" = lib.mkIf pkgs.stdenv.isLinux {
    source = ../lazygit/config.yml;
  };

  home.file."Library/Application Support/lazygit/config.yml" = lib.mkIf pkgs.stdenv.isDarwin {
    source = ../lazygit/config.yml;
  };

  home.packages =
    (with pkgs; [
      lazygit
      difftastic
      delta
    ])
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.pinentry_mac
      (pkgs.callPackage ./pinentry-touchid { })
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.pinentry-curses
    ];
}
