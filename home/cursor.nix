{
  config,
  lib,
  pkgs,
  herdr,
  tellur,
  llm-agents,
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
    "blender"
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
    "tellur-authoring" = {
      "SKILL.md" = "${tellur}/skills/tellur-authoring/SKILL.md";
      "SKILL.ja.md" = "${tellur}/skills/tellur-authoring/SKILL.ja.md";
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
  # nixpkgs の cursor-cli は更新が遅れがちなので、毎日 upstream に追従している
  # numtide/llm-agents.nix のパッケージを使う。
  # 自己アップデータを放置すると ~/.local/bin に NixOS では動かない汎用 Linux 用
  # バイナリを書き戻して PATH 上で Nix 版を隠してしまうため、常に
  # --disable-auto-update を付けて無効化する（環境変数や設定ファイルでの
  # 無効化手段は現状存在しない）。
  # ただしこのフラグは万全ではなく、2026-08-06 に実際にすり抜けて書き戻しが起きた。
  # 保険として下の home.sessionVariablesExtra で ~/.local/bin を PATH 末尾に置き、
  # 書き戻されても Nix 版が勝つようにしてある。
  config = lib.mkIf config.aspulse.profiles.agents.enable {
    home.packages =
      let
        cursorAgent = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent;
      in
      [
        (pkgs.symlinkJoin {
          name = "cursor-agent-no-auto-update";
          paths = [ cursorAgent ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/cursor-agent --add-flags --disable-auto-update
          '';
        })
      ];

    # home.sessionPath は PATH の先頭に追加するため、自己アップデータを持つツールが
    # ~/.local/bin に書き戻した汎用 Linux 向けバイナリが Nix 版を隠してしまう。
    # そこで sessionPath ではなく末尾へ追加して Nix 側を常に優先させる。
    home.sessionVariablesExtra = lib.optionalString pkgs.stdenv.isLinux ''
      export PATH="''${PATH:+''${PATH}:}$HOME/.local/bin"
    '';

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
  };
}
