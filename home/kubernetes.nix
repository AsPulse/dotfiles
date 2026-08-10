{
  config,
  lib,
  pkgs,
  ...
}:
{
  # kubie.yaml と krew の PATH もまとめて止める。クライアントが無いホストに
  # 設定だけ残しても読む側がいない。
  config = lib.mkIf config.aspulse.profiles.workstation.enable {
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
  };
}
