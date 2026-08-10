{
  config,
  lib,
  pkgs,
  ...
}:
{
  # rustup だけは常に入れる。ツールチェインの取得と rustfmt/clippy はどのホストでも要る。
  home.packages = [
    pkgs.rustup
  ]
  ++ lib.optionals config.aspulse.profiles.workstation.enable (
    with pkgs;
    [
      clang
      tokio-console
      # cargo-about not working in darwin
      cargo-insta
      cargo-expand
      cargo-cross
      cargo-release
      sccache
    ]
  );

  # rustc-wrapper に指定した実行ファイルが PATH に無いと cargo は起動直後に落ちる。
  # sccache を入れないホストにこの設定を配ってはいけない。
  home.file.".cargo/config.toml" = lib.mkIf config.aspulse.profiles.workstation.enable {
    text = ''
      [build]
      rustc-wrapper = "sccache"
    '';
  };
}
