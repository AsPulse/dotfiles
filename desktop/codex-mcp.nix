{
  config,
  lib,
  pkgs,
  ...
}:
let
  # 宣言そのものは home-manager 側の aspulse.mcpServers に置いたまま読み出す。
  # MCP サーバーは $HOME/.secret 配下や per-user profile を参照するユーザーの設定であり、
  # /etc に出すのは「Codex が Nix に所有させてくれる唯一のレイヤがそこしかない」ため。
  servers = config.home-manager.users.aspulse.aspulse.mcpServers or { };

  toCodex =
    server:
    if server.type == "http" then
      { inherit (server) url; }
    else
      { inherit (server) command; } // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; };

  tomlFormat = pkgs.formats.toml { };
in
{
  # Codex の設定レイヤは system (/etc/codex/config.toml) < user (~/.codex/config.toml) の
  # 優先度で重なり、mcp_servers はサーバー名ごとに個別マージされる。よって Nix は最下層の
  # system レイヤだけを丸ごと所有すればよく、Codex 自身が [tui.*] や [hooks.state] を
  # 書き戻す user 側には一切触れずに済む。ユーザーが手で足したサーバーとも共存する。
  #
  # 以前は home-manager の activation から `codex mcp add` を呼んでいたが、codex 0.144.0 は
  # HTTP サーバーの登録時に OAuth フローまで開始する。ブラウザのコールバックを待って
  # activation が固まり、systemd の TimeoutStartSec に達して rebuild ごと失敗していた。
  config = lib.mkIf (servers != { }) {
    environment.etc."codex/config.toml".source = tomlFormat.generate "codex-config.toml" {
      mcp_servers = lib.mapAttrs (_: toCodex) servers;
    };
  };
}
