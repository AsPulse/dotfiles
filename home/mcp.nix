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

  antigravityServers = lib.filterAttrs (_: s: s.antigravity) cfg;

  # Antigravity は HTTP サーバーの URL を url ではなく serverUrl で受け取る。
  toAntigravity =
    server:
    if server.type == "http" then
      { serverUrl = server.url; }
    else
      { inherit (server) command; } // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; };

  # ツール自身や UI からも書き換わる JSON に対し、.mcpServers へ Nix 側のサーバーだけを足し込む。
  # 同名のサーバーは Nix 側で上書きし、それ以外のキーとサーバーには触れない。
  # removed は Nix が宣言していてもこのファイルには配らないサーバー名で、
  # 以前の世代で書き込んだ分が残らないよう取り除く。
  mergeMcpServers = file: servers: removed: ''
    file=${file}
    mkdir -p "$(dirname "$file")"
    # 空ファイルは jq が何も出力せず中身が消えるので、存在しない場合と同じく {} から始める。
    if [ ! -s "$file" ]; then
      (
        umask 077
        echo '{}' >"$file"
      )
    fi

    tmp="$file.hm-mcp-tmp"
    # 先に権限ごと複製し、リダイレクトで中身だけ差し替えることでパーミッションを保つ。
    cp -p "$file" "$tmp"
    ${pkgs.jq}/bin/jq \
      --argjson servers ${lib.escapeShellArg (builtins.toJSON servers)} \
      --argjson removed ${lib.escapeShellArg (builtins.toJSON removed)} \
      '.mcpServers = (((.mcpServers // {}) | del(.[$removed[]])) + $servers)' "$file" >"$tmp"
    mv "$tmp" "$file"
  '';
in
{
  options.aspulse.mcpServers = lib.mkOption {
    default = { };
    description = ''
      Claude Code / Codex / cursor-agent / Antigravity に共通で配る MCP サーバー。
      どれも設定の受け口が異なるため、ここに登録するとそれぞれの流儀に変換して配られる。
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
          antigravity = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Antigravity にも配るか。Antigravity は OAuth トークンをサーバー名ではなく URL ごとに
              1 つしか持てないので、同じ URL を別アカウントで使い分けるサーバーは 1 つに絞る必要がある。
            '';
          };
        };
      }
    );
  };

  options.aspulse.antigravityMcpConfigFiles = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Antigravity の MCP サーバーをマージする mcp_config.json の絶対パス。
      T3 Code のように独自の GEMINI_HOME で agy を起動するものは、ここに自分の分を足す。
    '';
  };

  config = lib.mkIf (config.aspulse.profiles.agents.enable && cfg != { }) {
    aspulse.antigravityMcpConfigFiles = [
      "${config.home.homeDirectory}/.gemini/config/mcp_config.json"
    ];

    # Claude Code は MCP を settings.json では受け付けず、ユーザースコープの置き場は
    # ~/.claude.json しかない。Claude 自身が書き換える状態ファイルなので丸ごとは管理せず、
    # .mcpServers だけをマージする。
    home.activation.installClaudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      ${mergeMcpServers ''"$HOME/.claude.json"'' (lib.mapAttrs (_: toClaude) cfg) [ ]}
    '';

    # Antigravity は IDE と CLI が ~/.gemini/config/mcp_config.json を共有し、
    # Manage MCP Servers の UI からも同じファイルが編集されるため、Claude と同じくマージで配る。
    home.activation.installAntigravityMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      ${lib.concatMapStrings (
        file:
        mergeMcpServers (lib.escapeShellArg file) (lib.mapAttrs (_: toAntigravity) antigravityServers) (
          lib.attrNames (lib.filterAttrs (_: s: !s.antigravity) cfg)
        )
      ) config.aspulse.antigravityMcpConfigFiles}
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
