{
  config,
  lib,
  herdr,
  tellur,
  ...
}:
let
  codexSkillsDir = "${config.home.homeDirectory}/.codex/skills";
  codexStandaloneDir = "${config.home.homeDirectory}/.codex/packages/standalone/current";
  codexStandaloneBin = "${codexStandaloneDir}/codex";
  codexProfileBin = "${config.home.profileDirectory}/bin/codex";
  skillNames = [
    "pr-create"
    "pr-rename"
    "commit"
    "issue-create"
    "branch-create"
    "branch-rename"
    "zellij"
  ];
  installSkill = name: ''
    mkdir -p ${lib.escapeShellArg "${codexSkillsDir}/${name}/agents"}
    rm -f ${lib.escapeShellArg "${codexSkillsDir}/${name}/SKILL.md"}
    rm -f ${lib.escapeShellArg "${codexSkillsDir}/${name}/agents/openai.yaml"}
    install -m 0644 ${lib.escapeShellArg (toString ../codex/skills/${name}/SKILL.md)} \
      ${lib.escapeShellArg "${codexSkillsDir}/${name}/SKILL.md"}
    install -m 0644 ${lib.escapeShellArg (toString ../codex/skills/${name}/agents/openai.yaml)} \
      ${lib.escapeShellArg "${codexSkillsDir}/${name}/agents/openai.yaml"}
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
  installExternalSkill = name: files: ''
    rm -rf ${lib.escapeShellArg "${codexSkillsDir}/${name}"}
    mkdir -p ${lib.escapeShellArg "${codexSkillsDir}/${name}"}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (file: src: ''
        install -m 0644 ${lib.escapeShellArg (toString src)} \
          ${lib.escapeShellArg "${codexSkillsDir}/${name}/${file}"}
      '') files
    )}
  '';
in
{
  # Codex custom skills were not detected when home-manager exposed them as symlinks.
  # Place real files in ~/.codex/skills so Codex can discover them consistently.
  home.activation.installCodexSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg codexSkillsDir}
    ${lib.concatStringsSep "\n" (map installSkill skillNames)}
  '';

  home.activation.installCodexExternalSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg codexSkillsDir}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: files: installExternalSkill name files) externalSkills
    )}
  '';

  # Workaround for `codex remote-control`: the daemon currently insists on the
  # installer-managed standalone path. Point that fixed path at the Home Manager
  # profile binary while leaving a real installer-managed file untouched.
  home.activation.linkCodexStandaloneBinary = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg codexStandaloneDir}
    if [ ! -e ${lib.escapeShellArg codexStandaloneBin} ] || [ -L ${lib.escapeShellArg codexStandaloneBin} ]; then
      ln -sfn ${lib.escapeShellArg codexProfileBin} ${lib.escapeShellArg codexStandaloneBin}
    fi
  '';
}
