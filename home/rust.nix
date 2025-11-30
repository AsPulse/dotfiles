{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    clang
    tokio-console
    # cargo-about not working in darwin
    cargo-insta
    cargo-expand
    cargo-cross
    cargo-release
    sccache
  ];

}
