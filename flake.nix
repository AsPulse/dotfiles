{
  description = "AsPulse's public dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-module.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    lazygit.url = "github:jesseduffield/lazygit";
    flake-utils.url = "github:numtide/flake-utils";
    opencode.url = "github:anomalyco/opencode";
    herdr.url = "github:ogulcancelik/herdr/v0.7.3";
    # skills/tellur-authoring を取り込むためだけの入力なので flake としては評価しない。
    tellur.url = "github:comnipl/tellur";
    tellur.flake = false;
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs-module";
    llm-agents.url = "github:numtide/llm-agents.nix";
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
      opencode,
      herdr,
      tellur,
      nix-index-database,
      llm-agents,
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
        packages.zellij = pkgs.zellij;

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
              inherit
                opencode
                claude-code-nix
                herdr
                tellur
                nix-index-database
                llm-agents
                ;
            }
          );
      }
    );
}
