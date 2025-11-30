{ pkgs, ... }:
{

  home.packages = with pkgs; [
    kubectl
    krew
    kubeseal
    (pkgs.wrapHelm pkgs.kubernetes-helm {
      plugins = [ pkgs.kubernetes-helmPlugins.helm-diff ];
    })
    helmfile
    kubie
  ];

  home.sessionPath = [
    "$HOME/.krew/bin"
  ];

  home.file.".kube/kubie.yaml".source = ../terminal/kubie/kubie.yaml;
}
