{
  config,
  lib,
  pkgs,
  opencode,
  claude-code-nix,
  herdr,
  tellur,
  nix-index-database,
  llm-agents,
  kache,
  ...
}:
let
  profiles = config.aspulse.profiles;

  codexVersion = "0.164.0";
  codexReleases = {
    x86_64-linux = {
      asset = "codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-PsVQUxCWCNUDj35QdQ99Jfdo39dA/vBxqnEOJVm2Oqw=";
    };
    aarch64-linux = {
      asset = "codex-package-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-WRit1sfpzx4Uqa8bTA9L8dJKQ5A/qsJt9dxMAZ6pG9U=";
    };
    x86_64-darwin = {
      asset = "codex-package-x86_64-apple-darwin.tar.gz";
      hash = "sha256-z7KpmI1+pEhREWajV4mvB6AGXREX21Q1CxfUbPA9ApQ=";
    };
    aarch64-darwin = {
      asset = "codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-3ZnpCSJwaRpnvd574ErCg96p2o6Gy941bCzIUaeSBfo=";
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
    inherit
      herdr
      tellur
      llm-agents
      kache
      ;
  };

  home.packages =
    # どのホストでも読む・探す・見るのに要るもの。
    (with pkgs; [
      bat
      eza
      ripgrep
      fzf
      fd
    ])
    ++ lib.optionals profiles.workstation.enable (
      with pkgs;
      [
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
        _1password-cli
      ]
    )
    ++ lib.optionals profiles.agents.enable [
      claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      codexPackage
      # llm-agents.nix の grok は cursor-agent と同名の `agent` も入れてしまうので、`grok` だけを公開する。
      (pkgs.runCommand "grok" { } ''
        mkdir -p $out/bin
        ln -s ${llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.grok}/bin/grok $out/bin/grok
      '')
      # opencode's Linux build is currently broken upstream (fixed-output hash
      # mismatch for node_modules). Disabled for now.
      # opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.skimpdf
    ];

  imports = [
    nix-index-database.homeModules.nix-index
    ./profiles.nix
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
    ./open-macbook.nix
    ./claude.nix
    ./codex.nix
    ./cursor.nix
    ./mcp.nix
    ./mcp-context7.nix
    ./blender-cli.nix
    ./blacksmith.nix
    ./t3code.nix
  ];

  programs.home-manager.enable = true;

  home.sessionVariables = {
    # herdr-notepad は herdr 越しに nvim を開くラッパなので、herdr を運用しない
    # ホストでは素の nvim を指す。
    EDITOR = if profiles.workstation.enable then "herdr-notepad" else "nvim";
    COLORTERM = "truecolor";
  };
}
