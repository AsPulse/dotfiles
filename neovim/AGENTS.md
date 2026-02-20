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
    │   └── zellij.lua          # Zellij terminal integration
    └── util/
        ├── required.lua        # Auto-loader: scans directory, requires all .lua files
        └── command.lua         # Command utility helpers
```

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

## LSP SERVERS CONFIGURED

texlab, ts_ls, eslint, biome, denols, tailwindcss, dockerls, lua_ls, jsonls, yamlls, tombi, bashls, nixd, pyright, rust-analyzer (via rustaceanvim)
