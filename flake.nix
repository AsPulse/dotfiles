{
  description = "AsPulse's public dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-module.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    codex-nix.url = "github:sadjow/codex-nix";
    lazygit.url = "github:jesseduffield/lazygit";
    flake-utils.url = "github:numtide/flake-utils";
    opencode.url = "github:albertov/opencode/dev";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-module,
      flake-utils,
      neovim-nightly-overlay,
      lazygit,
      claude-code-nix,
      codex-nix,
      opencode,
      ...
    }:
    let
      overlays = [
        neovim-nightly-overlay.overlays.default
        lazygit.overlays.default
      ];

    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        pkgs-module = import nixpkgs-module {
          inherit system overlays;
          config.allowUnfree = true;
        };

      in
      {

        formatter = pkgs.writeShellApplication {
          name = "aspulse-dotfiles-formatter";
          runtimeInputs = with pkgs; [
            stylua
            nixfmt-rfc-style
          ];
          text = ''
            stylua --glob '**/*.lua' neovim
            fd "$@" -t f -e nix -x nixfmt '{}'
          '';
        };

        checks.formatting-neovim =
          pkgs.runCommand "check-neovim-formatting"
            {
              buildInputs = with pkgs; [ stylua ];
              src = self;
            }
            ''
              cd $src
              stylua --check --glob '**/*.lua' neovim
              touch $out
            '';

        checks.formatting-nix =
          pkgs.runCommand "check-nix-formatting"
            {
              buildInputs = with pkgs; [
                nixfmt-rfc-style
                fd
                gitMinimal
              ];
              src = self;
            }
            ''
              cp -r --no-preserve=mode $src src
              cd src
              git init --quiet && git add .
              fd "$@" -t f -e nix -x nixfmt '{}'
              if ! git diff --exit-code; then
                exit 1
              fi
              touch $out
            '';

        desktopModules =
          { ... }@args:
          import ./desktop/configuration.nix (
            args
            // {
              pkgs = pkgs-module;
            }
          );

        homeModules =
          { ... }@args:
          import ./home/home.nix (
            args
            // {
              pkgs = pkgs-module;
              inherit codex-nix opencode claude-code-nix;
            }
          );
      }
    );
}
