// kana-rule.conf を skkeleton の register_kanatable が取る JSON へ変換する。
//
// 大西配列はキーボード側 (conductor-keymap.json の base レイヤー) で実現する
// ため、kana-rule.conf は打鍵がそのまま文字として届く前提の文字空間で記述
// する。macSKK は kana-rule.conf をそのまま読めるので、変換が要るのは
// skkeleton だけ。
//
// usage: deno run --allow-read kana-rule-to-json.ts <kana-rule.conf>

function unescapeRule(s: string): string {
  return s.replaceAll('&comma;', ',').replaceAll('&sharp;', '#');
}

function main() {
  const [path] = Deno.args;
  const lines = Deno.readTextFileSync(path).replace(/\n$/, '').split('\n');

  const rules: [string | null, string][] = lines.map((line) => {
    if (line === '' || line.startsWith('#')) return [null, line];
    const sep = line.indexOf(',');
    return [unescapeRule(line.slice(0, sep)), line.slice(sep + 1)];
  });

  const inputs = rules.map(([inp]) => inp).filter((inp) => inp !== null);
  const dups = [...new Set(inputs.filter((i, n) => inputs.indexOf(i) !== n))];
  if (dups.length > 0) {
    console.error(`duplicate inputs: ${JSON.stringify(dups.sort())}`);
    Deno.exit(1);
  }

  const table: Record<string, [string, string]> = {};
  for (const [inp, rest] of rules) {
    if (inp === null) continue;
    const fields = rest.split(',').map(unescapeRule);
    table[inp] = [fields[0], fields[3] ?? ''];
  }
  console.log(JSON.stringify(table, null, 1));
}

main();
