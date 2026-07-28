{
  lib,
  python3Packages,
  fetchgit,
  makeWrapper,
  blender,
}:
# Blender Foundation 公式の MCP サーバー (Blender Lab)。25k star のサードパーティ実装
# (ahujasid/blender-mcp) とは別物で、そちらは bl_info 形式のため Blender 5.0 以降の
# extension 化と噛み合わない。公式版は blender_version_min = 5.1.0 を宣言していて
# nixpkgs の 5.1.2 と一致する。
#
# 上流は `uv run` を前提にしているが、依存は docutils/mcp/pyyaml の 3 つだけで
# すべて nixpkgs にあるため、通常の Python アプリケーションとして閉じられる。
python3Packages.buildPythonApplication rec {
  pname = "blender-mcp";
  version = "1.0.0";
  pyproject = true;

  src = fetchgit {
    url = "https://projects.blender.org/lab/blender_mcp.git";
    rev = "v${version}";
    hash = "sha256-nt+sHozi+epJdu6GXcWGd33C9uewN+Ao8WP9Y2upPQc=";
  };

  # リポジトリには addon/ (Blender 側) と mcp/ (サーバー側) が同居している。
  sourceRoot = "${src.name}/mcp";

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    docutils
    mcp
    pyyaml
  ];

  nativeBuildInputs = [ makeWrapper ];

  # 上流のテストは実際に Blender を起動する統合テストを含むため走らせない。
  doCheck = false;
  pythonImportsCheck = [ "blmcp" ];

  # `*_for_cli` 系のツールは background Blender を別プロセスとして起動するが、その探索は
  # BLENDER_PATH または PATH 上の `blender` に頼っている。MCP サーバーは各エージェントから
  # stdio で起動されるので PATH に Blender がある保証がなく、ここで解決しておく。
  # BLENDER_MCP_PORT は既定値と同じだが、複数の Blender を使い分けたくなったときに
  # 触る場所を明示しておく意図で置いている。
  postFixup = ''
    wrapProgram $out/bin/blender-mcp \
      --set-default BLENDER_PATH ${lib.getExe blender} \
      --set-default BLENDER_MCP_PORT 9876
  '';

  meta = {
    description = "Blender 公式 MCP サーバー (Blender Lab)";
    homepage = "https://www.blender.org/lab/mcp-server/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "blender-mcp";
    platforms = lib.platforms.linux;
  };
}
