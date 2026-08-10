{
  config,
  lib,
  pkgs,
  ...
}:
let
  # 判断そのものは home-manager 側の aspulse.profiles にあるので、そこから読み出す。
  # system と home で別々にトグルを持つと必ず片方だけ切り替える事故が起きる。
  workstation = config.home-manager.users.aspulse.aspulse.profiles.workstation.enable or true;
in
{
  imports = [
    ./codex-mcp.nix
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [ ./darwin.nix ]
  ++ lib.optionals pkgs.stdenv.isLinux [ ./linux.nix ];

  environment.systemPackages =
    (with pkgs; [
      git
      vim
      wget
      curl
      btop
      unzip
    ])
    ++ lib.optionals workstation (
      with pkgs;
      [
        nix-prefetch-github
        pkg-config
        openssl.dev
        evcxr
        rclone
      ]
    );

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  programs.zsh.enable = true;
}
