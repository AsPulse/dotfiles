{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  services.tailscale.enable = true;

  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

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
      {
        name = "nix-daemon";
        type = "BG_CPUIO";
      }
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

      {
        name = "cargo";
        type = "BG_CPUIO";
      }
      {
        name = "rustc";
        type = "BG_CPUIO";
      }
      {
        name = "rust-analyzer";
        type = "BG_CPUIO";
      }
    ];
  };
}
