{ pkgs, ... }: {
  home.packages = with pkgs; [
    turbo
    nodejs_24
  ];
}
