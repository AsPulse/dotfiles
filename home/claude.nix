{
  config,
  lib,
  pkgs,
  ...
}:
let
  claudeSkillsDir = "${config.home.homeDirectory}/.claude/skills";
  claudeSkillNames = [
    "pr-create"
    "pr-rename"
    "commit"
    "issue-create"
    "branch-create"
    "branch-rename"
    "zellij"
  ];
  installClaudeSkill = name: ''
    rm -rf ${lib.escapeShellArg "${claudeSkillsDir}/${name}"}
    mkdir -p ${lib.escapeShellArg "${claudeSkillsDir}/${name}"}
    install -m 0644 ${lib.escapeShellArg (toString ../claude/skills/${name}/SKILL.md)} \
      ${lib.escapeShellArg "${claudeSkillsDir}/${name}/SKILL.md"}
  '';
  claude-statusline = pkgs.rustPlatform.buildRustPackage {
    pname = "claude-statusline";
    version = "0.1.0";
    src = ../claude/statusline;
    cargoLock.lockFile = ../claude/statusline/Cargo.lock;
  };
  plotPython = pkgs.python3.withPackages (
    ps: with ps; [
      plotly
      numpy
      scipy
    ]
  );
  claude-rate-limit-plot = pkgs.writeShellScriptBin "claude-rate-limit-plot" ''
    exec ${plotPython}/bin/python3 ${../claude/statusline/plot.py} "$@"
  '';
in
{
  home.packages = [ claude-rate-limit-plot ];
  home.file.".claude/statusline" = {
    source = "${claude-statusline}/bin/claude-statusline";
    executable = true;
  };
  # Claude skills were not detected reliably when home-manager exposed them as
  # symlinks. Place real files in ~/.claude/skills so Claude Code can discover them.
  # rm -rf each skill dir first to replace any previous home.file-managed symlinks.
  home.activation.installClaudeSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg claudeSkillsDir}
    ${lib.concatStringsSep "\n" (map installClaudeSkill claudeSkillNames)}
  '';

  home.file.".claude/hooks/gh-pr-create-guard.sh" = {
    source = ../claude/hooks/gh-pr-create-guard.sh;
    executable = true;
  };
}
