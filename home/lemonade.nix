{
  pkgs,
  lib,
  ...
}:
let
  lemonadeServerHost = "aspulses-macbook-air";
  lemonadeServerAllow = "127.0.0.1,::1,100.125.219.92,fd7a:115c:a1e0::b83b:db5c";
  lemonadeClientHost = if pkgs.stdenv.isLinux then lemonadeServerHost else "localhost";

  # `xdg-open` / `gh` などが BROWSER の値を空白で split して先頭をコマンドとして
  # 扱うケースがあるため、引数込みの単一バイナリとしてラップする。
  lemonade-open = pkgs.writeShellScriptBin "lemonade-open" ''
    # Tailscale または Mac が到達不能なとき、Lemonade のローカル fallback が
    # `xdg-open` -> `lemonade-open` と再帰するのを失敗で打ち切る。
    export BROWSER=${pkgs.coreutils}/bin/false
    exec ${pkgs.lemonade}/bin/lemonade --host=${lemonadeServerHost} open "$@"
  '';
in
{
  home.packages = [
    pkgs.lemonade
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [ lemonade-open ];

  # server / client 両方が同じ toml を読む。Linux client は Tailscale MagicDNS で
  # Mac に直接接続し、Mac client は従来どおり localhost を使う。
  home.file.".config/lemonade.toml".text = ''
    port = 2489
    host = "${lemonadeClientHost}"
    allow = "${lemonadeServerAllow}"
  '';

  # macOS: SSH 越しに飛んできた URL を GUI セッションで開けるよう、user agent
  # として常駐させる。
  launchd.agents.lemonade = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.lemonade}/bin/lemonade"
        "server"
        "--allow=${lemonadeServerAllow}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/aspulse/Library/Logs/lemonade.out.log";
      StandardErrorPath = "/Users/aspulse/Library/Logs/lemonade.err.log";
    };
  };

  # NixOS: BROWSER を経由してくる URL は全部 Tailscale 越しに Mac に投げる。
  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    BROWSER = "lemonade-open";
  };
}
