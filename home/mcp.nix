{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.aspulse.mcpServers;

  # Claude は type を明示した形式を受け付ける。
  toClaude =
    server:
    if server.type == "http" then
      { inherit (server) type url; }
    else
      {
        inherit (server) type command;
      }
      // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; };

  # cursor-agent は url があれば HTTP、command があれば stdio として解釈する。
  toCursor =
    server:
    if server.type == "http" then
      { inherit (server) url; }
    else
      { inherit (server) command; } // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; };
in
{
  options.aspulse.mcpServers = lib.mkOption {
    default = { };
    description = ''
      Claude Code / Codex / cursor-agent に共通で配る MCP サーバー。
      3 つとも設定の受け口が異なるため、ここに登録するとそれぞれの流儀に変換して配られる。
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [
              "stdio"
              "http"
            ];
            default = "stdio";
          };
          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg != { }) {
    # Claude Code は MCP を settings.json では受け付けず、ユーザースコープの置き場は
    # ~/.claude.json しかない。Claude 自身が書き換える状態ファイルなので丸ごとは管理せず、
    # .mcpServers だけをマージする。
    home.activation.installClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      claude_json="$HOME/.claude.json"
      if [ ! -f "$claude_json" ]; then
        (
          umask 077
          echo '{}' >"$claude_json"
        )
      fi

      tmp="$claude_json.hm-mcp-tmp"
      # 先に権限ごと複製し、リダイレクトで中身だけ差し替えることでパーミッションを保つ。
      cp -p "$claude_json" "$tmp"
      ${pkgs.jq}/bin/jq --argjson servers ${
        lib.escapeShellArg (builtins.toJSON (lib.mapAttrs (_: toClaude) cfg))
      } \
        '.mcpServers = ((.mcpServers // {}) + $servers)' "$claude_json" >"$tmp"
      mv "$tmp" "$claude_json"
    '';

    # Codex 分はここでは配らない。config.toml は Codex 自身が書き戻す状態ファイルなので、
    # 優先度が一段低い system レイヤ (/etc/codex/config.toml) を Nix が所有する形にしてある。
    # desktop/codex-mcp.nix を参照。

    # cursor-agent は ~/.cursor/mcp.json だけを見る。skills と違い symlink でも読めるため
    # home.file でそのまま生成してよい。
    home.file.".cursor/mcp.json".text = builtins.toJSON {
      mcpServers = lib.mapAttrs (_: toCursor) cfg;
    };
  };
}
