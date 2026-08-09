{ pkgs }:
{
  # macSKK はかなルールと ん のシフト入力ルールを 1 ファイルで読む
  macskk = pkgs.runCommand "kana-rule-onishi-macskk.conf" { } ''
    cat ${./kana-rule.conf} ${./kana-rule.onishi-macskk.conf} > $out
  '';

  # skkeleton のテーブルファイルパーサは &comma; を解釈できず、入力側に
  # カンマを含むルールを表現できないため JSON で register_kanatable に渡す
  skkeletonJson = pkgs.runCommand "kana-rule-onishi.json" { } ''
    DENO_DIR=$TMPDIR ${pkgs.deno}/bin/deno run --allow-read \
      ${./kana-rule-to-json.ts} ${./kana-rule.conf} > $out
  '';
}
