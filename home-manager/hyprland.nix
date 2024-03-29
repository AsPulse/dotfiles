{ pkgs, ... }: {

  imports = [
    ./hyprland/rofi.nix
    ./hyprland/vivaldi.nix
  ];

  home.packages = with pkgs; [
    kitty
    inkscape
    obs-studio
    gimp
    mongodb-compass
    keepassxc
    (pkgs.callPackage ./discord-browser {  })
    (pkgs.callPackage ./youtube-wayland {  })
    (pkgs.callPackage ./cookieclicker-browser {  })
  ];

  home.file.".config/hypr/hyprland.conf" = {
    source = ../hyprland/hyprland.conf;
  };
}
