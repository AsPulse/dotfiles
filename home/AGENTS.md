# HOME-MANAGER MODULES

One `.nix` file per tool/domain. Each is imported by `home.nix`.

## ADDING A NEW MODULE

1. Create `<tool>.nix` in this directory
2. Add to `imports` list in `home.nix`
3. Use `{ pkgs, ... }:` function signature (add `lib` if platform conditionals needed)

## FILE MAP

| File | Domain | Key contents |
|------|--------|-------------|
| `home.nix` | Entry point | `home.packages` (CLI tools), `imports`, `sessionPath`, `sessionVariables` |
| `terminal.nix` | Shell + terminal | zsh config, aliases (`cat`→`bat`, `ls`→`eza`), completions, ghostty/starship/zellij |
| `git.nix` | Git + GitHub | git settings, delta pager, gh CLI + extensions, GPG signing, lazygit placement |
| `neovim.nix` | Editor | Places `../neovim` → `~/.config/nvim` and `../tsnip` → `~/.vim/tsnip` |
| `node.nix` | Node.js | nodejs + pnpm |
| `python.nix` | Python | python3 + uv |
| `deno.nix` | Deno | deno runtime |
| `rust.nix` | Rust | rustup |
| `docker.nix` | Docker | docker CLI + compose |
| `latex.nix` | LaTeX | texliveFull, custom .sty placement to `~/texmf/` |
| `typst.nix` | Typst | typst + typstfmt + tinymist LSP |
| `kubernetes.nix` | K8s | kubectl, helm, krew, kubie config placement |
| `direnv.nix` | direnv | direnv + nix-direnv integration |
| `ime.nix` | IME | macSKK kana-rule via `home.activation` (TCC workaround) |
| `pinentry-touchid/` | GPG | Custom pinentry derivation for Touch ID on macOS |

## CONVENTIONS

- Platform conditionals: `lib.mkIf pkgs.stdenv.isDarwin` / `.isLinux`
- Config file placement: `home.file."<dest>".source = <src>` — never manual symlinks
- macOS vs Linux config paths differ (e.g., lazygit: `Library/Application Support/` vs `.config/`)
- Packages from flake inputs use `<input>.packages.${pkgs.stdenv.hostPlatform.system}.default`

## ANTI-PATTERNS

- Never bundle multiple unrelated tools in one file
- Never put personal identity (email, GPG key) here — that's `private/home/home.nix`
