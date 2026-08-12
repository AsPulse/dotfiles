# NEOVIM CONFIG

Full Neovim configuration using lazy.nvim. Placed to `~/.config/nvim` by `home/neovim.nix`.

## STRUCTURE
```
neovim/
├── init.lua                    # Bootstrap: loads configs → installs lazy.nvim → loads plugins → loads commands
├── lazy-lock.json              # Plugin lockfile (COMMITTED — do not gitignore)
└── lua/
    ├── configs/                # Core vim settings (loaded before plugins)
    │   ├── basic.lua           # encoding, search, splits, leader=space
    │   ├── indent.lua          # Indentation settings
    │   ├── stopmove.lua        # Movement restrictions
    │   └── workspacevim.lua    # Workspace-specific vim settings
    ├── plugin-settings/        # Plugin specs (see plugin-settings/AGENTS.md)
    │   └── <name>.lua          # Each returns LazyPluginSpec or LazyPluginSpec[]
    ├── commands/               # Custom commands (loaded after plugins)
    │   ├── clipboard.lua       # Clipboard integration
    │   ├── export-jumper.lua   # Export navigation
    │   ├── nohighlight.lua     # Search highlight clearing
    │   ├── showHiGroup.lua     # Highlight group inspector
    │   ├── snipdeck.lua        # Snipdeck commands/keymaps (module lives in lua/snipdeck/)
    │   └── zellij.lua          # Zellij terminal integration
    ├── snipdeck/               # Prompt snippet picker (self-contained, no plugin deps)
    │   ├── init.lua            # Public API: setup / open / save
    │   ├── config.lua          # Defaults (~/snippets, usage file under stdpath('data'))
    │   ├── store.lua           # Snippet scan, read/write, usage counts
    │   └── ui.lua              # Floating-window TUI (prompt / list / preview / help)
    └── util/
        ├── required.lua        # Auto-loader: scans directory, requires all .lua files
        └── command.lua         # Command utility helpers
```

`lua/snipdeck/` is NOT auto-required — `required.under()` only scans `configs/`, `plugin-settings/`,
`commands/`. Entry point is `commands/snipdeck.lua`, which lazily requires the module.

## HOW IT WORKS

1. `init.lua` calls `required.under('configs')` — auto-requires every `.lua` in `lua/configs/`
2. lazy.nvim is bootstrapped from git if missing
3. `required.under('plugin-settings')` collects all plugin specs
4. `lazy.setup(specs)` installs/loads all plugins
5. `required.under('commands')` loads custom commands last
6. Lockfile path: `~/dotfiles/public/neovim/lazy-lock.json` (hardcoded absolute)

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add a plugin | `lua/plugin-settings/<name>.lua` — return `LazyPluginSpec` |
| Change vim options | `lua/configs/basic.lua` or create new file in `lua/configs/` |
| Add a custom command | `lua/commands/<name>.lua` |
| Change the snippet picker | `lua/snipdeck/` (UI is `ui.lua`, storage is `store.lua`) |
| Change LSP settings | `lua/plugin-settings/lsp.lua` |
| Change keybindings | Relevant plugin file's `keys` table, or `lua/configs/` |

## CONVENTIONS

- **Formatting**: `stylua` — 2-space indent, single quotes, collapse simple statements
- **Plugin specs**: each file returns `LazyPluginSpec` (single) or `LazyPluginSpec[]` (multiple)
- **Type annotations**: use `--- @type LazyPluginSpec` or `--- @type LazyPluginSpec[]` at top of plugin files
- **Leader key**: `<space>` (set in `configs/basic.lua`)
- **Auto-loading**: files in `configs/`, `plugin-settings/`, `commands/` are auto-required — no manual registration needed

## ANTI-PATTERNS

- Do NOT manually require plugin files — `required.under()` handles discovery
- Do NOT delete or gitignore `lazy-lock.json`
- Do NOT put plugin config in `configs/` — plugins go in `plugin-settings/`
- Uses **forked nvim-lspconfig** (`AsPulse/nvim-lspconfig` branch `feat(lsp)/smarter-typescript-project-detection`) — do not replace with upstream without checking

## KEY PLUGINS

| Plugin | Purpose | File |
|--------|---------|------|
| snacks.nvim | Explorer, picker, lazygit, bufdelete, notifications | `snacks.lua` |
| nvim-cmp | Completion | `cmp.lua` |
| nvim-lspconfig (fork) | LSP client configs | `lsp.lua` |
| lspsaga.nvim | LSP UI (rename, code action, hover) | `lsp.lua` |
| treesitter | Syntax highlighting, text objects | `treesitter.lua` |
| bufferline | Tab/buffer bar | `bufferline.lua` |
| skkeleton | Japanese IME in-editor | `skkeleton.lua` |
| copilot.lua | AI completion | `copilot.lua` |

## SNIPDECK (prompt snippet picker)

AI エージェントへ渡すプロンプトを `~/snippets` から呼び出す自前 TUI。herdr-notepad (素の nvim) で
使うため外部プラグインには依存しない (floating window + `matchfuzzypos` のみ)。

| 入口 | 動作 |
|------|------|
| `:Snipdeck` / `<leader>sn` | ピッカーを開く |
| `:SnipdeckSave [name]` / `<leader>sw` | バッファ (visual では選択範囲) をスニペット化 |

ピッカー内: `↵` カーソル位置へ挿入 / `^a` 末尾追記 / `^r` 全置換 / `^y` ヤンク / `^e` ファイルを開く /
`^x` 削除 / `^g` ソート切替 (頻度→更新→名前) / `^t`,`^n` 移動 (大西配列の物理 J/K) / `^f`,`^b` プレビュースクロール。

- 使用回数は `stdpath('data')/snipdeck/usage.json` に記録する — マシン固有の状態なので dotfiles には置かない
- herdr 内 (`HERDR_ENV=1`) では開いている間だけ `herdr pane zoom` で自ペインを広げ、閉じるときに戻す
  (`herdr_zoom = false` で無効化)。`--current` は**サーバー側のフォーカス中ペイン**を指すので、必ず
  `$HERDR_PANE_ID` を明示して渡す。単一ペインのタブでは no-op (`reason: single_pane`) になり
  `zoom_changed: false` が返るので、自分で変えたときだけ戻す
- 名前で当たらないクエリは本文検索へフォールバックし、リストに `` バッジを出す
- 枠付き float の `row`/`col` は**枠の左上**、`width`/`height` は**枠の内側**を指す (`ui.lua` の `win_config`)
- 画面が `10 行 × 40 桁` 未満なら開かずに通知する。ヘルプ行はリストの高さが足りなければ `hide` する

## LSP SERVERS CONFIGURED

texlab, ts_ls, eslint, biome, denols, tailwindcss, dockerls, lua_ls, jsonls, yamlls, tombi, bashls, nixd, pyright, rust-analyzer (via rustaceanvim)
