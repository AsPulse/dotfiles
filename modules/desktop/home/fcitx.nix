{ pkgs, ... }: {
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-mozc
      fcitx5-skk-qt
      fcitx5-configtool
    ];
  };

  home.packages = with pkgs; [
    libskk
  ];
}
