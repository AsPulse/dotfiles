{ pkgs, ... }:
let
  claude-statusline = pkgs.rustPlatform.buildRustPackage {
    pname = "claude-statusline";
    version = "0.1.0";
    src = ../claude/statusline;
    cargoLock.lockFile = ../claude/statusline/Cargo.lock;
  };
in
{
  home.file.".claude/statusline" = {
    source = "${claude-statusline}/bin/claude-statusline";
    executable = true;
  };
  home.file.".claude/skills/pr-create/SKILL.md".source = ../claude/skills/pr-create/SKILL.md;
  home.file.".claude/skills/pr-rename/SKILL.md".source = ../claude/skills/pr-rename/SKILL.md;
  home.file.".claude/skills/commit/SKILL.md".source = ../claude/skills/commit/SKILL.md;
  home.file.".claude/skills/issue-create/SKILL.md".source = ../claude/skills/issue-create/SKILL.md;
  home.file.".claude/skills/branch-create/SKILL.md".source = ../claude/skills/branch-create/SKILL.md;
  home.file.".claude/skills/branch-rename/SKILL.md".source = ../claude/skills/branch-rename/SKILL.md;
}
