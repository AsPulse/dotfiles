{
  config,
  lib,
  ...
}:
let
  cursorSkillsDir = "${config.home.homeDirectory}/.cursor/skills";
  cursorSkillNames = [
    "commit"
    "pr-create"
    "pr-rename"
    "issue-create"
    "branch-create"
    "branch-rename"
    "zellij"
  ];
  installCursorSkill = name: ''
    mkdir -p ${lib.escapeShellArg "${cursorSkillsDir}/${name}"}
    rm -f ${lib.escapeShellArg "${cursorSkillsDir}/${name}/SKILL.md"}
    install -m 0644 ${lib.escapeShellArg (toString ../cursor/skills/${name}/SKILL.md)} \
      ${lib.escapeShellArg "${cursorSkillsDir}/${name}/SKILL.md"}
  '';
in
{
  programs.zsh.shellAliases = {
    cursor-cli = "NIXPKGS_ALLOW_UNFREE=1 nix run github:NixOS/nixpkgs/nixpkgs-unstable#cursor-cli --impure";
  };

  # Cursor skills were not detected reliably when home-manager exposed them as
  # symlinks. Place real files in ~/.cursor/skills so Cursor can discover them.
  home.activation.installCursorSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg cursorSkillsDir}
    ${lib.concatStringsSep "\n" (map installCursorSkill cursorSkillNames)}
  '';
}
