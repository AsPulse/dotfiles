# PUBLIC DOTFILES

Shareable Nix configurations. Own git repo, published to GitHub as `AsPulse/dotfiles`.

## STRUCTURE
```
public/
├── flake.nix          # Exports desktopModules + homeModules (consumed by private/)
├── home/              # home-manager modules — one .nix per tool
├── neovim/            # Full nvim config (see neovim/AGENTS.md)
├── desktop/           # nix-darwin system config (systemPackages, PAM, nix settings)
├── terminal/          # ghostty, starship, kubie raw config files
├── tsnip/             # Deno-based TypeScript snippet definitions for tsnip.nvim
├── lazygit/           # lazygit config.yml (placed via home.file in git.nix)
├── ime/               # macSKK kana-rule.conf (placed via home.activation, not home.file)
├── latex/             # Custom .sty files (placed via home.file in latex.nix)
├── zellij_layouts/    # Zellij .kdl layout files
├── .github/           # CI workflows (format checks) + Renovate config
├── stylua.toml        # Lua formatter config
└── renovate.json      # GitHub Actions SHA pin management
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Add a flake input | `flake.nix` `inputs` — also wire through `outputs` args |
| Add a system package | `desktop/configuration.nix` `environment.systemPackages` |
| Add a home-manager module | `home/<tool>.nix` + add to `home/home.nix` `imports` |
| Add a user package | `home/home.nix` `home.packages` |
| Place a config file | Relevant `home/*.nix` using `home.file."<path>".source` |
| Edit CI | `.github/workflows/format.yaml` |

## CONVENTIONS

- `flake.nix` exports two module functions: `desktopModules` and `homeModules` — both take `system` via `eachDefaultSystem`
- Overlays for neovim-nightly and lazygit are applied in `pkgs-module`, not `pkgs` (separate nixpkgs instance)
- `allowUnfree = true` only on `pkgs-module`
- Formatter (`nix fmt`) runs both `nixfmt` and `stylua` in one script

## ANTI-PATTERNS

- Never add personal identity data here — that belongs in `private/`
- Never add raw config files without a corresponding `home.file` placement in a `.nix` module
- ime/kana-rule.conf uses `home.activation` (not `home.file`) due to macOS TCC sandbox — do not change to `home.file`
