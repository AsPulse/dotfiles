import { Snippet } from "https://deno.land/x/tsnip_vim@v0.5/mod.ts";

export const env: Snippet = {
  name: "env",
  text: "\\begin{${1:align*}}\n  \n\\end{${1:align*}}",
  // envName という一度だけの入力プロンプトを表示
  // type: "single_line" のみで、content 用の param は不要
  params: [
    { name: "envName", type: "single_line" },
  ],
  render: ({ envName }, { postCursor }) => {
    // envName に入力がなければデフォルトで "align*" を使う
    const name = envName?.text ?? "align*";
    // postCursor によってカーソルを \begin と \end の間に移動
    return `\\begin{${name}}\n  ${postCursor}\n\\end{${name}}`;
  },
};

export default { env };
