{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  services.tailscale.enable = true;

  # 対話的プロセス（nvim, zellij, Claude Code 等）の応答性を守るため、
  # 重いビルドを idle スケジューラに落とす。
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # nix-daemon を経由しない直接実行（shell からの cargo build や nix 評価等）を
  # カバーするため ananicy-cpp を有効化する。意図しない挙動を避けるため
  # デフォルトのルール集は読み込まず、下の extraRules だけ適用する。
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.runCommand "ananicy-empty-rules" { } ''
      mkdir -p $out/etc/ananicy.d/00-default
    '';
    # cachyos のデフォルトルール集と同値
    extraTypes = [
      {
        type = "BG_CPUIO";
        nice = 16;
        ioclass = "idle";
        sched = "idle";
        latency_nice = 11;
      }
    ];
    extraRules = [
      # nix-daemon 本体とその子は daemonCPUSchedPolicy 側で既に idle なので除外
      {
        name = "nix";
        type = "BG_CPUIO";
      }
      {
        name = "nix-store";
        type = "BG_CPUIO";
      }
      {
        name = "nix-instantiate";
        type = "BG_CPUIO";
      }
      {
        name = "nix-build";
        type = "BG_CPUIO";
      }
      {
        name = "nom";
        type = "BG_CPUIO";
      }

      # rust-analyzer は対話的 LSP なので意図的に除外
      {
        name = "cargo";
        type = "BG_CPUIO";
      }
      {
        name = "rustc";
        type = "BG_CPUIO";
      }
    ];
  };
}
