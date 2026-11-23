{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.aspulse.t3code;

  # nixpkgs の t3code はソースビルドで upstream に大きく遅れているため、release tarball
  # (Node SEA + ネイティブモジュール) を NixOS 向けに patchelf して使う。独自パッチを当てた
  # fork (AsPulse/t3code) の release を使う。形式は upstream の公式 release と同じ。
  t3code = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "t3code";
    version = "0.1.11";

    src = pkgs.fetchurl {
      url = "https://github.com/AsPulse/t3code/releases/download/aspulse-v${finalAttrs.version}/t3-${finalAttrs.version}-linux-x64.tar.gz";
      hash = "sha256-1NRsOrRs5YBl7YvX+fW5dQqaOUKuupkCSJztT1JshE4=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.vulkan-loader
    ];
    # musl 向けのネイティブモジュールも同梱されているが、glibc 環境では読み込まれない。
    autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

    # strip は SEA に埋め込まれたアプリ本体を壊す。
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec/t3code $out/bin
      cp -r . $out/libexec/t3code
      ln -s $out/libexec/t3code/t3 $out/bin/t3
      runHook postInstall
    '';

    # T3 は preview 用ブラウザを本体に埋め込んだバージョン名のディレクトリから探す。previewBrowserVersion と
    # 食い違ったまま T3 を上げると、置いたブラウザが使われず汎用 Linux 向けのものを落としてしまう。
    postInstall = ''
      grep -aqF 'VERSION = "${previewBrowserVersion}"' $out/libexec/t3code/t3 \
        || { echo "T3 expects a different chrome-headless-shell than ${previewBrowserVersion}; update previewBrowserVersion" >&2; exit 1; }
    '';

    meta.platforms = [ "x86_64-linux" ];
  });

  previewBrowserVersion = "157.0.8103.78";

  # T3 は preview 用に chrome-headless-shell を ~/.t3/tools へ落として使うが、Google のログインは
  # headless-shell を弾く。T3 が探す場所に普通の Chrome を置き、Chrome 本体の headless で動かす。
  # 窓ありにはできない。T3 は起動直後に最初のタブをすべて閉じ、窓ありの Chrome は最後の窓が
  # 閉じた時点で終了してしまう。
  previewBrowser = pkgs.writeTextFile {
    name = "t3code-preview-browser";
    destination = "/chrome-headless-shell";
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      exec ${lib.getExe pkgs.google-chrome} "$@"
    '';
  };
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

    home.file.".t3/tools/chrome-headless-shell/linux64/${previewBrowserVersion}".source =
      previewBrowser;

    # 公式の `t3 service install` は自前で unit を書き、`t3 update` で自身を差し替えるため使わない。
    systemd.user.services.t3code = {
      Unit = {
        Description = "T3 Code server";
        # 再起動すると配下で動いているエージェントがすべて止まるため、switch では差し替えだけにして
        # 再起動は手動で行う。
        X-RestartIfChanged = false;
      };
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
