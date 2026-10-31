{ config, lib, ... }:
let
  tailscale = "${config.services.tailscale.package}/bin/tailscale";
  # 有効化の判断は home-manager 側の aspulse.t3code に一本化する。
  cfg = config.home-manager.users.aspulse.aspulse.t3code or { enable = false; };
in
{
  # T3 Code (home-manager の systemd user service) を tailnet に HTTPS で公開する。
  # services.tailscale.serve は Tailscale Services (svc:) 用で、タグ付きデバイスと admin 側の
  # サービス定義が要るうえ node の serve 設定を丸ごと上書きするため使わない。
  # t3 自身の --tailscale-serve は aspulse を tailscale の operator にする必要があるため、root から張る。
  config = lib.mkIf cfg.enable {
    systemd.services.tailscale-serve-t3code = {
      description = "Expose T3 Code on the tailnet via Tailscale Serve";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${tailscale} serve --bg --https=8443 http://127.0.0.1:${toString cfg.port}";
        ExecStop = "${tailscale} serve --https=8443 off";
        # 起動直後は tailscaled がまだ tailnet に繋がっておらず serve が失敗することがある。
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };
}
