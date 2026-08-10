{ lib, ... }:
# ホストごとに「どこまで入れるか」を切り替えるトグル。
# public 側のモジュールにホスト固有の事情 (この Mac には要らない、等) を直接書くと
# 汎用モジュールが濁るため、判断は private/home/machines/<hostName>.nix に出す。
# 既定は全部 true なので、何も指定しないホストは従来どおり全部入りになる。
{
  options.aspulse.profiles = {
    workstation.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        開発ワークステーションとして使うか。言語ツールチェイン・Kubernetes・運用 CLI・
        文書処理など、実際にビルドや運用作業をするマシンにしか要らないものを制御する。
        false でも閲覧と編集、Git 操作に要るものは残る。
      '';
    };

    agents.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        AI エージェント CLI (Claude Code / Codex / cursor-agent) を入れるか。
        false にするとパッケージだけでなく skills・共通指示・MCP サーバーの配布も止まる。
        パッケージだけ消して設定が残る状態を作らないため、まとめてこのトグルで扱う。
      '';
    };
  };
}
