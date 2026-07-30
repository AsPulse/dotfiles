{
  lib,
  pkgs,
  ...
}:
let
  # Blender Lab 公式 MCP プロジェクトの成果物。MCP サーバー本体は使わず、
  # アドオン (Blender 側の TCP サーバー) と同梱ドキュメントだけを取り出す。
  # blender-cli はそのソケットに直接喋るので、MCP クライアントを挟まない。
  version = "1.0.0";

  addonZip = pkgs.fetchurl {
    url = "https://projects.blender.org/lab/blender_mcp/releases/download/v${version}/mcp-${version}.zip";
    hash = "sha256-g4w0SfAQFchhKQZYrmfxIvCEb3iC9gpd/aDvfmqbhAM=";
  };

  # bpy の API リファレンスと user manual の RST。上流も「grep で直接読め」と
  # 案内している形式なので、エージェントには Grep させる。
  docs = pkgs.stdenvNoCC.mkDerivation {
    pname = "blender-mcp-docs";
    inherit version;

    src = pkgs.fetchgit {
      url = "https://projects.blender.org/lab/blender_mcp.git";
      rev = "v${version}";
      hash = "sha256-nt+sHozi+epJdu6GXcWGd33C9uewN+Ao8WP9Y2upPQc=";
    };

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r mcp/blmcp/data/* "$out/"
      runHook postInstall
    '';

    meta = {
      description = "Blender Python API リファレンスと user manual の RST";
      license = lib.licenses.gpl3Plus;
    };
  };

  # フィルタ後の内容でコンテンツアドレスし、target/ の更新で再ビルドさせない。
  blender-cli-src = lib.cleanSourceWith {
    src = ../blender-cli;
    filter =
      path: _type:
      let
        base = baseNameOf path;
      in
      base != "target" && base != ".gitignore";
  };

  blender-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "blender-cli";
    version = "0.1.0";
    src = blender-cli-src;
    cargoLock.lockFile = blender-cli-src + "/Cargo.lock";

    nativeBuildInputs = [ pkgs.makeWrapper ];

    # blender は素のまま渡してよい。アドオンの導入も --online-mode も
    # blender-cli 側が面倒を見るので、ラップ済みの Blender を用意する必要はない。
    postFixup = ''
      wrapProgram $out/bin/blender-cli \
        --set-default BLENDER_CLI_BLENDER ${lib.getExe pkgs.blender} \
        --set-default BLENDER_CLI_ADDON_ZIP ${addonZip} \
        --set-default BLENDER_CLI_DOCS ${docs} \
        --set-default BLENDER_CLI_SWAYMSG ${lib.getExe' pkgs.sway "swaymsg"}
    '';

    meta = {
      description = "複数の Blender インスタンスをソケット越しに操作する CLI";
      mainProgram = "blender-cli";
      platforms = lib.platforms.linux;
    };
  };
in
{
  # Blender を動かすのは NixOS マシンだけなので、Darwin に closure を引き込まない。
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [ blender-cli ];
  };
}
