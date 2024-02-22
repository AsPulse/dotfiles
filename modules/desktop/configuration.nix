{ pkgs, ... }: {
  system.stateVersion = "23.11";
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_xanmod;

  networking = {
    hostName = "aspulse-nixos";
    networkmanager.enable = true;
  };

  imports = [
    ./docker.nix
    ./font.nix
  ];

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    btop
    gcc
    clang
    unzip
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
    extraGroups = [ "wheel" ];
    isNormalUser = true;
    uid = 1000;
  };

  programs.zsh.enable = true;

}
