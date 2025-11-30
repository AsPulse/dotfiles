{
  description = "AsPulse's public dotfiles";

  inputs = {
		nixpkgs-module.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    codex-nix.url = "github:sadjow/codex-nix";
    lazygit.url = "github:jesseduffield/lazygit";
		flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs-module, flake-utils, neovim-nightly-overlay, lazygit, codex-nix, ... }: let
    overlays = [
      neovim-nightly-overlay.overlays.default
			lazygit.overlays.default
    ];

		in flake-utils.lib.eachDefaultSystem (system: let
				pkgs-module = import nixpkgs-module {
					inherit system overlays;
					config.allowUnfree = true;
				};
			in {

				desktopModules = { ... }@args:
					import ./desktop/configuration.nix (args // {
						pkgs = pkgs-module;
					});

				homeModules = { ... }@args:
					import ./home/home.nix (args // {
						pkgs = pkgs-module;
						inherit codex-nix;
					});
			});
}
