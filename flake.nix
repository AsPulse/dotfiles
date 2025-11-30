{
  description = "AsPulse's public dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    codex-nix.url = "github:sadjow/codex-nix";
    lazygit.url = "github:jesseduffield/lazygit";
  };

  outputs = { nixpkgs, neovim-nightly-overlay, lazygit, codex-nix, ... }: let
    systems = [ "aarch64-darwin" ];
    overlays = [
      neovim-nightly-overlay.overlays.default
        lazygit.overlays.default
    ];

    pkgs = system: import nixpkgs {
      inherit system overlays;
      config = {
        allowUnfree = true;
      };
    };
  in {

    desktopModules = nixpkgs.lib.genAttrs systems (system: { ... }@args:
        import ./desktop/configuration.nix (args // {
            pkgs = pkgs system;
          })
        );


    homeModules = nixpkgs.lib.genAttrs systems (system: { ... }@args:
        import ./home/home.nix (args // {
            pkgs = pkgs system;
            inherit codex-nix;
          })
        );

  };
}
