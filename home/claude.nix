{
  config,
  lib,
  pkgs,
  herdr,
  tellur,
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
  externalSkills = {
    "herdr" = {
      "SKILL.md" = "${herdr}/SKILL.md";
    };
    "tellur-authoring" = {
      "SKILL.md" = "${tellur}/skills/tellur-authoring/SKILL.md";
      "SKILL.ja.md" = "${tellur}/skills/tellur-authoring/SKILL.ja.md";
    };
  };
  installExternalClaudeSkill = name: files: ''
    rm -rf ${lib.escapeShellArg "${claudeSkillsDir}/${name}"}
    mkdir -p ${lib.escapeShellArg "${claudeSkillsDir}/${name}"}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (file: src: ''
        install -m 0644 ${lib.escapeShellArg (toString src)} \
          ${lib.escapeShellArg "${claudeSkillsDir}/${name}/${file}"}
      '') files
    )}
  '';
  # フィルタ後の内容でコンテンツアドレスされた src にすることで、
  # リポジトリ内の無関係な変更による再ビルドを防ぐ
  claude-statusline-src = lib.cleanSourceWith {
    src = ../claude/statusline;
    filter =
      path: _type:
      let
        base = baseNameOf path;
      in
      base != "target" && base != ".gitignore" && base != "plot.py" && base != "CLAUDE.md";
  };
  claude-statusline = pkgs.rustPlatform.buildRustPackage {
    pname = "claude-statusline";
    version = "0.1.0";
    src = claude-statusline-src;
    cargoLock.lockFile = claude-statusline-src + "/Cargo.lock";
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

  home.activation.installClaudeExternalSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg claudeSkillsDir}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: files: installExternalClaudeSkill name files) externalSkills
    )}
  '';

  home.file.".claude/hooks/gh-pr-create-guard.sh" = {
    source = ../claude/hooks/gh-pr-create-guard.sh;
    executable = true;
  };
}
