{
  config,
  lib,
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
in
{
  # Codex custom skills were not detected when home-manager exposed them as symlinks.
  # Place real files in ~/.codex/skills so Codex can discover them consistently.
  home.activation.installCodexSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg codexSkillsDir}
    ${lib.concatStringsSep "\n" (map installSkill skillNames)}
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
