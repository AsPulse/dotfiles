{ pkgs, codex-nix, ... }:
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  home.packages = with pkgs; [
    bat
    eza
    ripgrep
    fzf
    fd
    dust
    jq
    yq
    imagemagick
    ghostscript
    neofetch
    nkf
    jellyfin-ffmpeg
    act
    google-cloud-sdk
    cilium-cli
    mongosh
    mongodb-tools
    skimpdf
    subversion
    ngrok
    claude-code
    codex-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  imports = [
    ./terminal.nix
    ./git.nix
    ./neovim.nix
    ./node.nix
    ./python.nix
    ./deno.nix
    ./rust.nix
    ./docker.nix
    ./latex.nix
    ./typst.nix
    ./kubernetes.nix
    ./direnv.nix
    ./ime.nix
  ];

  programs.home-manager.enable = true;

  home.sessionPath = [
    "$HOME/.krew/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
