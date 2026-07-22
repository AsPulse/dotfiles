// kana-rule.conf (文字空間) を大西配列の物理打鍵空間へ写像する。
//
// kana-rule.conf は「どの文字を打つとどのかなになるか」を文字の意味で
// 記述したソースとして維持し、OS 側のキーマップは QWERTY のまま、
// IME のローマ字テーブルだけで大西配列を実現する。そのため各ルールの
// 入力文字列を「大西配列でその文字が刻印されたキーが QWERTY として
// 発する文字」へ置換して出力する。
//
// usage: deno run --allow-read convert-onishi.ts {macskk|json} <kana-rule.conf>

const ONISHI_TO_QWERTY: Record<string, string> = {
  l: 'w',
  u: 'e',
  ',': 'r',
  '.': 't',
  f: 'y',
  w: 'u',
  r: 'i',
  y: 'o',
  e: 'a',
  i: 's',
  a: 'd',
  o: 'f',
  '-': 'g',
  k: 'h',
  t: 'j',
  n: 'k',
  s: 'l',
  h: ';',
  ';': 'b',
  g: 'n',
  d: 'm',
  m: ',',
  j: '.',
  b: '/',
  '/': '-',
};

function unescapeRule(s: string): string {
  return s.replaceAll('&comma;', ',').replaceAll('&sharp;', '#');
}

function escapeRule(s: string): string {
  return s.replaceAll(',', '&comma;').replaceAll('#', '&sharp;');
}

function convert(s: string): string {
  return [...unescapeRule(s)].map((c) => ONISHI_TO_QWERTY[c] ?? c).join('');
}

function main() {
  const [format, path] = Deno.args;
  const lines = Deno.readTextFileSync(path).replace(/\n$/, '').split('\n');

  const rules: [string | null, string][] = lines.map((line) => {
    if (line === '' || line.startsWith('#')) return [null, line];
    const sep = line.indexOf(',');
    return [convert(line.slice(0, sep)), line.slice(sep + 1)];
  });

  const inputs = rules.map(([inp]) => inp).filter((inp) => inp !== null);
  const dups = [...new Set(inputs.filter((i, n) => inputs.indexOf(i) !== n))];
  if (dups.length > 0) {
    console.error(`converted inputs collide: ${JSON.stringify(dups.sort())}`);
    Deno.exit(1);
  }

  if (format === 'macskk') {
    const out = rules.map(([inp, rest]) => (inp === null ? rest : `${escapeRule(inp)},${rest}`));
    console.log(out.join('\n'));
  } else if (format === 'json') {
    const table: Record<string, [string, string]> = {};
    for (const [inp, rest] of rules) {
      if (inp === null) continue;
      const fields = rest.split(',').map(unescapeRule);
      table[inp] = [fields[0], fields[3] ?? ''];
    }
    console.log(JSON.stringify(table, null, 1));
  } else {
    console.error(`unknown format: ${format}`);
    Deno.exit(1);
  }
}

main();
