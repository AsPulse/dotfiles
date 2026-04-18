{
  pkgs,
  lib,
  ...
}:
let
  # `xdg-open` / `gh` などが BROWSER の値を空白で split して先頭をコマンドとして
  # 扱うケースがあるため、引数込みの単一バイナリとしてラップする。
  lemonade-open = pkgs.writeShellScriptBin "lemonade-open" ''
    exec ${pkgs.lemonade}/bin/lemonade open "$@"
  '';
in
{
  home.packages = [
    pkgs.lemonade
  ] ++ lib.optionals pkgs.stdenv.isLinux [ lemonade-open ];

  # server / client 両方が同じ toml を読む。`allow` は server 用、`host`/`port`
  # は client 用。SSH RemoteForward 経由で 2489 をループバック越しに通す。
  home.file.".config/lemonade.toml".text = ''
    port = 2489
    host = "localhost"
    allow = "127.0.0.1"
  '';

  # macOS: SSH 越しに飛んできた URL を GUI セッションで開けるよう、user agent
  # として常駐させる。
  launchd.agents.lemonade = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.lemonade}/bin/lemonade"
        "server"
        "--allow=127.0.0.1"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/Users/aspulse/Library/Logs/lemonade.out.log";
      StandardErrorPath = "/Users/aspulse/Library/Logs/lemonade.err.log";
    };
  };

  # NixOS: BROWSER を経由してくる URL は全部 SSH 元の Mac に投げる。
  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    BROWSER = "lemonade-open";
  };
}
