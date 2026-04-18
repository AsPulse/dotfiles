{ pkgs, ... }:
let
  ghosttyPkg = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
in
{

  home.packages = [
    ghosttyPkg
    pkgs.zellij
  ];

  home.file.".terminfo".source = "${ghosttyPkg.terminfo}/share/terminfo";

  home.file.".config/ghostty/config".source = ../terminal/ghostty/config;

  home.file.".config/zellij/config.kdl".text =
    let
      base = builtins.readFile ../terminal/zellij/config.kdl;
    in
    if pkgs.stdenv.isLinux then
      builtins.replaceStrings [ "mouse_mode true" ] [ "mouse_mode false" ] base
    else
      base;

  home.file.".config/starship.toml".source = ../terminal/starship/starship.toml;

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
