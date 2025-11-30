{
  description = "AsPulse's public dotfiles";

  inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
		nixpkgs-module.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    codex-nix.url = "github:sadjow/codex-nix";
    lazygit.url = "github:jesseduffield/lazygit";
		flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-module, flake-utils, neovim-nightly-overlay, lazygit, codex-nix, ... }: let
    overlays = [
      neovim-nightly-overlay.overlays.default
			lazygit.overlays.default
    ];

		in flake-utils.lib.eachDefaultSystem (system: let
				pkgs = import nixpkgs {
					inherit system;
				};
				pkgs-module = import nixpkgs-module {
					inherit system overlays;
					config.allowUnfree = true;
				};

				
		in {

			formatter = pkgs.writeShellApplication {
				name = "aspulse-dotfiles-formatter";
				runtimeInputs = [ pkgs.stylua ];
				text = ''
					stylua --glob '**/*.lua' neovim
				'';
			};

			checks.formatting-neovim = pkgs.runCommand "check-neovim-formatting" {
				buildInputs = [ pkgs.stylua ];
				src = self;
			} ''
				cd $src
				stylua --check --glob '**/*.lua' neovim
				touch $out
			'';

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
