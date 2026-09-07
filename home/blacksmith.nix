{
  config,
  lib,
  pkgs,
  ...
}:
let
  version = "0.4.58";

  # 公式の配布は get.blacksmith.sh のインストーラ経由のみで GitHub リリースが無い。
  # チャンネル部分に `latest` ではなく `v<version>` を渡した URL だけが不変なので、
  # 追従は Renovate に任せずここの pin を手で上げる。
  releases = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-C1SkOY6bNTRNj7MokXA9ijkzQ/UAGRTXSC+T0GjHaCI=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-K/PnJGQU4v0RPTIUV3u4lRAVrtpXV50fNux13FwFxxY=";
    };
  };
  release = releases.${pkgs.stdenv.hostPlatform.system};

  blacksmith = pkgs.stdenvNoCC.mkDerivation {
    pname = "blacksmith";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://clireleases.blacksmith.sh/cli/v${version}/linux/${release.arch}/blacksmith";
      inherit (release) hash;
    };

    dontUnpack = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/blacksmith"
      # 自前の自動更新は毎回の起動で走るが Nix store を書き換えられず失敗する。
      # バージョンは上の pin で管理するので試行ごと止める。rsync は testbox の
      # ローカル差分同期が呼ぶ。
      wrapProgram "$out/bin/blacksmith" \
        --set BLACKSMITH_DISABLE_AUTO_UPDATE 1 \
        --prefix PATH : ${lib.makeBinPath [ pkgs.rsync ]}
      runHook postInstall
    '';

    meta = {
      description = "Blacksmith CLI";
      homepage = "https://docs.blacksmith.sh/blacksmith-cli/overview";
      license = lib.licenses.unfree;
      mainProgram = "blacksmith";
      platforms = builtins.attrNames releases;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  # 使うのは CI キャッシュとジョブの調査、testbox へのローカル差分同期で、
  # どれも実際にビルドを回すホストの作業。
  config = lib.mkIf (config.aspulse.profiles.workstation.enable && pkgs.stdenv.isLinux) {
    home.packages = [ blacksmith ];
  };
}
