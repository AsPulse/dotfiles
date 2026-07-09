{
  lib,
  pkgs,
  opencode,
  claude-code-nix,
  herdr,
  nix-index-database,
  ...
}:
let
  codexVersion = "0.144.0";
  codexReleases = {
    x86_64-linux = {
      asset = "codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-awPS2JkQh0+lvie2F2Iddjj5BuiR/Yy0CvPSh2qKNv0=";
    };
    aarch64-linux = {
      asset = "codex-package-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-1YvgTm7oBIM8JbWGhp8fpn8n8L3D85EFoqm6zvFnrkI=";
    };
    x86_64-darwin = {
      asset = "codex-package-x86_64-apple-darwin.tar.gz";
      hash = "sha256-EFbICViGOxPevV2u5et7m9b4YjahFx0hsAni3O6odj4=";
    };
    aarch64-darwin = {
      asset = "codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-RYSiQ/+KZxJQvHFvicWlDtWZF6mDkKz9/6Psts/luzQ=";
    };
  };
  codexRelease = codexReleases.${pkgs.stdenv.hostPlatform.system};

  codexPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = codexVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/${codexRelease.asset}";
      inherit (codexRelease) hash;
    };

    sourceRoot = ".";
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R bin codex-package.json codex-path codex-resources "$out/"
      runHook postInstall
    '';

    meta = {
      description = "OpenAI Codex CLI";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = builtins.attrNames codexReleases;
    };
  };
in
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

  _module.args = {
    inherit herdr;
  };

  home.packages =
    (with pkgs; [
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
      nkf
      jellyfin-ffmpeg
      act
      process-compose
      google-cloud-sdk
      cilium-cli
      mongosh
      mongodb-tools
      subversion
      ngrok
      cloudflared
      claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      codexPackage
      # opencode's Linux build is currently broken upstream (fixed-output hash
      # mismatch for node_modules). Disabled for now.
      # opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    ])
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.skimpdf
    ];

  imports = [
    nix-index-database.homeModules.nix-index
    ./comma.nix
    ./terminal.nix
    ./opencode.nix
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
    ./skkeleton.nix
    ./mosh.nix
    ./ha.nix
    ./lemonade.nix
    ./cc-clip.nix
    ./open-macbook.nix
    ./claude.nix
    ./codex.nix
    ./cursor.nix
  ];

  programs.home-manager.enable = true;

  home.sessionPath = [
    "$HOME/.krew/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    COLORTERM = "truecolor";
  };
}
