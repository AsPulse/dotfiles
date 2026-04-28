{
  config,
  lib,
  ...
}:
let
  codexSkillsDir = "${config.home.homeDirectory}/.codex/skills";
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
}
