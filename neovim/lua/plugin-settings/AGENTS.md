# PLUGIN SETTINGS

Each file returns a lazy.nvim plugin spec. Auto-loaded by `required.under('plugin-settings')` in `init.lua`.

## ADDING A PLUGIN

1. Create `<name>.lua` in this directory
2. Return a `LazyPluginSpec` table (single plugin) or `LazyPluginSpec[]` (multiple related plugins)
3. Add `--- @type LazyPluginSpec` or `--- @type LazyPluginSpec[]` annotation at top
4. No other registration needed — auto-discovered

## CONVENTIONS

- One file per plugin domain (e.g., `lsp.lua` contains lspconfig + lspsaga + dressing + lsp-colors)
- Use lazy-loading: `event`, `cmd`, `keys`, or `lazy = true` where possible
- Format with `stylua`: 2-space indent, single quotes, collapse simple statements

## FILE MAP

| File | Plugin(s) | Lazy trigger |
|------|-----------|-------------|
| `bufferline.lua` | bufferline.nvim | TabNew event |
| `cmp.lua` | nvim-cmp + sources | InsertEnter |
| `colortheme.lua` | Color scheme | — |
| `comment.lua` | Comment.nvim | — |
| `confirm-quit.lua` | Confirm before quit | — |
| `copilot.lua` | copilot.lua | InsertEnter |
| `integration.lua` | External tool integrations | — |
| `lexima.lua` | Auto-pairs | InsertEnter |
| `lsp.lua` | lspconfig (fork) + lspsaga + dressing + lsp-colors + inlay-hints | BufEnter/LspAttach |
| `lualine.lua` | Status line | — |
| `motion.lua` | Motion plugins | — |
| `outline.lua` | Code outline | — |
| `persistence.lua` | Session persistence | — |
| `remote-sshfs.lua` | Remote SSH filesystem | — |
| `scroll.lua` | Smooth scroll | — |
| `skkeleton.lua` | Japanese IME (SKK) | — |
| `snacks.lua` | snacks.nvim (explorer, picker, lazygit, bufdelete) | keys |
| `startup.lua` | Start screen | — |
| `tex.lua` | LaTeX-specific plugins | — |
| `todo-comments.lua` | TODO/FIXME highlighting | — |
| `treesitter.lua` | Treesitter + text objects | — |
| `trouble.lua` | Diagnostics list | — |
| `tsnip.lua` | TypeScript snippets | — |
| `typst.lua` | Typst support | — |
| `ui.lua` | UI enhancements | — |
| `utils.lua` | Utility plugins | — |
