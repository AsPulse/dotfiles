{
  config,
  lib,
  pkgs,
  kache,
  ...
}:
let
  workstation = config.aspulse.profiles.workstation.enable;
  # 上流のテストは約 2000 件あり、ビルド時間の大半を占める。テストは上流の CI に任せる。
  kachePkg = kache.packages.${pkgs.stdenv.hostPlatform.system}.kache.overrideAttrs {
    doCheck = false;
  };
  kacheExe = lib.getExe kachePkg;
  # デーモンは他の worktree を git で探して target を把握する。
  # サービスの PATH は最小限なので git を明示的に渡す。
  daemonPath = lib.makeBinPath [ pkgs.git ];
in
{
  # rustup だけは常に入れる。ツールチェインの取得と rustfmt/clippy はどのホストでも要る。
  home.packages = [
    pkgs.rustup
  ]
  ++ lib.optionals workstation (
    with pkgs;
    [
      clang
      tokio-console
      # cargo-about not working in darwin
      cargo-insta
      cargo-expand
      cargo-cross
      cargo-release
      kachePkg
    ]
  );

  # rustc-wrapper に指定した実行ファイルが PATH に無いと cargo は起動直後に落ちる。
  # kache を入れないホストにこの設定を配ってはいけない。
  # [env] は kache init が書き込む内容と同じ。nix develop の中では devshell の cc が
  # PATH の先頭に来て shims を素通りするため、cc crate が CC より優先する HOST_CC で kache を挟む。
  home.file.".cargo/config.toml" = lib.mkIf workstation {
    text = ''
      [build]
      rustc-wrapper = "kache"

      [env]
      HOST_CC = "kache cc"
      HOST_CXX = "kache c++"
      CC_KNOWN_WRAPPER_CUSTOM = "kache"
    '';
  };

  # workspace の bin やテスト実行ファイルは編集のたびに中身が変わり、ほぼ再利用されないのにストアの大半を占める。
  xdg.configFile."kache/config.toml" = lib.mkIf workstation {
    text = ''
      [cache]
      cache_executables = false
      gc_max_age_hours = 336
    '';
  };

  # cc や gcc を PATH から呼ぶ C/C++ ビルドを kache 経由にする。shims は本物のコンパイラより前に置く必要がある。
  home.sessionPath = lib.mkIf workstation [ "${kachePkg}/shims" ];

  # kache はデーモンなしでも動くが、ストアの GC と消えた worktree の target 掃除はデーモンが担う。
  # サービス名は kache daemon install が作るものに合わせ、kache daemon start/restart から扱えるようにする。
  systemd.user.services.kache = lib.mkIf (workstation && pkgs.stdenv.isLinux) {
    Unit.Description = "kache build cache daemon";
    Service = {
      ExecStart = "${kacheExe} daemon run";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [ "PATH=${daemonPath}" ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  launchd.agents.kache = lib.mkIf (workstation && pkgs.stdenv.isDarwin) {
    enable = true;
    config = {
      Label = "ninja.kunobi.kache";
      ProgramArguments = [
        kacheExe
        "daemon"
        "run"
      ];
      EnvironmentVariables.PATH = daemonPath;
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 5;
    };
  };
}
