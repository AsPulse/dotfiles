{ pkgs }:
let
  convert =
    name: format:
    pkgs.runCommand name { } ''
      DENO_DIR=$TMPDIR ${pkgs.deno}/bin/deno run --allow-read \
        ${./convert-onishi.ts} ${format} ${./kana-rule.conf} > $out
    '';
in
{
  # macSKK はかなルールと Shift 記号の変換開始ルールを 1 ファイルで読む
  macskk = pkgs.runCommand "kana-rule-onishi-macskk.conf" { } ''
    cat ${convert "kana-rule-onishi.conf" "macskk"} ${./kana-rule.onishi-macskk.conf} > $out
  '';

  # skkeleton のテーブルファイルパーサは &comma; を解釈できず、入力側に
  # カンマを含む「ま行」を表現できないため JSON で register_kanatable に渡す
  skkeletonJson = convert "kana-rule-onishi.json" "json";
}
