{ inputs, pkgs, ... }: {
  system.stateVersion = "23.11";
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;

  networking = {
    hostName = "aspulse-nixos";
    networkmanager = {
      enable = true;
    };
  };

  environment.etc = {
    "resolv.conf".text = "nameserver 1.1.1.1\nnameserver 8.8.8.8\n";
  };

  time.timeZone = "Asia/Tokyo";

  imports = [
    ./docker.nix
    ./font.nix
    ./hyprland.nix
    ./rclone.nix
    ./nvidia.nix
    ./bluetooth.nix
    ./wireguard.nix
    ./k8s.nix
    ./steam.nix
  ] ++ (with inputs.nixos-hardware.nixosModules; [
    common-pc-ssd
    common-pc-hdd
  ]);

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    btop
    gcc
    clang
    unzip
    lshw
    nix-prefetch-github
    parted
    gparted
    openssl
    pkg-config
  ];
  environment.variables.EDITOR = "vim";

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
  };
  nixpkgs.config.allowUnfree = true;

  users.users.aspulse = {
    shell = pkgs.zsh;
    createHome = true;
    home = "/home/aspulse";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "jackaudio"
      "networkmanager"
    ];
    isNormalUser = true;
    uid = 1000;
  };

  programs.zsh.enable = true;

}
