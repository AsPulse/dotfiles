{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.aspulse.t3code;

  # nixpkgs の t3code はソースビルドで upstream に大きく遅れているため、公式の release
  # tarball (Node SEA + ネイティブモジュール) を NixOS 向けに patchelf して使う。
  t3code = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "t3code";
    version = "0.1.3";

    src = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-linux-x64.tar.gz";
      hash = "sha256-Y80PBUfu9iu07OJ/p3m7+eK6hTHMaFQlaLqeeIONxoQ=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    # strip は SEA に埋め込まれたアプリ本体を壊す。
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec/t3code $out/bin
      cp -r . $out/libexec/t3code
      ln -s $out/libexec/t3code/t3 $out/bin/t3
      runHook postInstall
    '';

    meta.platforms = [ "x86_64-linux" ];
  });
in
{
  options.aspulse.t3code = {
    enable = lib.mkEnableOption ''
      T3 Code サーバーを systemd user service として常駐させるか。NixOS 側の
      desktop/t3code.nix もこの値を読んで tailnet への公開を張る
    '';

    port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = "T3 Code が 127.0.0.1 で listen する port。";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ t3code ];

    # 公式の `t3 service install` は自前で unit を書き、`t3 update` で自身を差し替えるため使わない。
    systemd.user.services.t3code = {
      Unit.Description = "T3 Code server";
      Service = {
        WorkingDirectory = config.home.homeDirectory;
        Environment = [
          # user unit にはログインシェルの PATH が無く、エージェント CLI (claude, codex) や git を見つけられない。
          "PATH=/etc/profiles/per-user/${config.home.username}/bin:${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin"
        ];
        ExecStart = "${t3code}/bin/t3 serve --host 127.0.0.1 --port ${toString cfg.port} --no-browser";
        KillMode = "mixed";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
