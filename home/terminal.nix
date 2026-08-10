{
  config,
  lib,
  pkgs,
  herdr,
  ...
}:
let
  profiles = config.aspulse.profiles;
  ghosttyPkg = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
  herdrPkg = herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  herdr-notepad = pkgs.rustPlatform.buildRustPackage {
    pname = "herdr-notepad";
    version = "0.1.0";
    src = lib.cleanSourceWith {
      src = ../terminal/herdr-notepad;
      filter =
        path: _type:
        let
          base = baseNameOf path;
        in
        base != "target" && base != ".gitignore";
    };
    cargoLock.lockFile = ../terminal/herdr-notepad/Cargo.lock;
    doCheck = false;
    env = {
      HERDR_BIN = lib.getExe herdrPkg;
      NVIM_BIN = lib.getExe pkgs.neovim;
    };
  };
in
{

  home.packages = [
    ghosttyPkg
    herdrPkg
  ]
  # zellij は herdr と役割が重なる予備の多重化。herdr-notepad は EDITOR 用ラッパで
  # herdr のセッションがある前提なので、どちらもワークステーションでだけ入れる。
  ++ lib.optionals profiles.workstation.enable [
    pkgs.zellij
    herdr-notepad
  ];

  home.file.".terminfo".source = "${ghosttyPkg.terminfo}/share/terminfo";

  home.file.".config/ghostty/config".source = ../terminal/ghostty/config;

  home.file.".config/zellij/config.kdl" = lib.mkIf profiles.workstation.enable {
    text =
      let
        base = builtins.readFile ../terminal/zellij/config.kdl;
      in
      if pkgs.stdenv.isLinux then
        builtins.replaceStrings [ "mouse_mode true" ] [ "mouse_mode false" ] base
      else
        base;
  };

  home.file.".config/starship.toml".source = ../terminal/starship/starship.toml;

  home.file.".config/herdr/config.toml".source = ../terminal/herdr/config.toml;

  programs.zsh = {
    enable = true;
    autocd = false;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting = {
      enable = true;
    };
    shellAliases = {
      cat = "bat";
      ls = "eza --icons --classify";
      la = "eza --all --icons --classify";
      ll = "eza --long --all --git --icons";
    };

    initContent = ''
      zmodload zsh/complist
      autoload -Uz compinit; compinit -C
      setopt menu_complete
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors \'\'

      [[ $commands[kubectl] ]] && source <(kubectl completion zsh)
      [[ $commands[helm]    ]] && source <(helm completion zsh)
      [[ $commands[gh]      ]] && eval "$(gh completion -s zsh)"
      [[ $commands[docker]  ]] && docker completion zsh >/dev/null 2>&1 && source <(docker completion zsh)

      autoload -U edit-command-line
      zle -N edit-command-line
      bindkey -e
      bindkey '^Xe' edit-command-line
    '';
  };

  programs.starship = {
    enable = true;
  };
}
