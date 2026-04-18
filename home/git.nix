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

  # Linux gpg must not spawn a local agent — signing goes through the Mac's
  # gpg-agent via SSH RemoteForward, and a local agent would claim the socket.
  programs.gpg.settings = lib.mkIf pkgs.stdenv.isLinux {
    no-autostart = true;
  };

  home.file.".gnupg/gpg-agent.conf" = lib.mkIf pkgs.stdenv.isDarwin {
    text = ''
      pinentry-program ${(pkgs.callPackage ./pinentry-touchid { }).outPath}/bin/pinentry-touchid
    '';
  };

  # Parent dir of the RemoteForward-ed gpg-agent socket. Lives in tmpfs.
  home.activation.ensureGpgSocketDir = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      runtime_dir="''${XDG_RUNTIME_DIR:-}"
      [ -z "$runtime_dir" ] && runtime_dir="/run/user/$(id -u)"
      if [ -d "$runtime_dir" ]; then
        mkdir -p "$runtime_dir/gnupg"
        chmod 700 "$runtime_dir/gnupg"
      fi
    ''
  );

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
    ];
}
