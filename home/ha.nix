{ pkgs, ... }:
let
  ha = pkgs.fetchFromGitHub {
    owner = "kawarimidoll";
    repo = "ha";
    rev = "cac6373719b6dc17410ed7dd42a6a814787bfb21";
    hash = "sha256-SM+vkMNYToxh5nBmoU44ERIlSWzZPg5co6+8fuxrkl8=";
  };
in
{
  programs.zsh.initContent = ''
    source ${ha}/ha.sh
    compdef _ha ha
  '';
}
