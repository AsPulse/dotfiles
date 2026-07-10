{
  config,
  lib,
  herdr,
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
  externalCursorSkills = {
    "herdr" = {
      "SKILL.md" = "${herdr}/SKILL.md";
    };
  };
  installExternalCursorSkill = name: files: ''
    rm -rf ${lib.escapeShellArg "${cursorSkillsDir}/${name}"}
    mkdir -p ${lib.escapeShellArg "${cursorSkillsDir}/${name}"}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (file: src: ''
        install -m 0644 ${lib.escapeShellArg (toString src)} \
          ${lib.escapeShellArg "${cursorSkillsDir}/${name}/${file}"}
      '') files
    )}
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

  home.activation.installCursorExternalSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu

    mkdir -p ${lib.escapeShellArg cursorSkillsDir}
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: files: installExternalCursorSkill name files) externalCursorSkills
    )}
  '';
}
