{ ... }:
{
  virtualisation.docker.enable = true;
  services.tailscale.enable = true;

  # 対話的プロセス（nvim, zellij, Claude Code 等）の応答性を守るため、
  # nix-daemon のビルドを CPU/IO ともに idle クラスで走らせる
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
}
