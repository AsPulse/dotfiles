{ config, lib, ... }:
{
  # ライブラリやフレームワークのドキュメントを引くために使う。共通指示が調べ物の手段として
  # Context7 を挙げているので 3 ツールすべてに配る。API キーなしでも接続でき、キーを足すと
  # レート制限が緩和される。
  aspulse.mcpServers = lib.mkIf config.aspulse.profiles.agents.enable {
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
    };
  };
}
