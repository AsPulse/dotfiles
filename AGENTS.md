# PUBLIC DOTFILES

Shareable Nix configurations. Own git repo, published to GitHub as `AsPulse/dotfiles`.

Consumed by `private/` on two host classes: **macOS (aarch64-darwin)** via nix-darwin and **NixOS (x86_64-linux)** via the NixOS module.

## STRUCTURE
```
public/
├── flake.nix          # Exports desktopModules + homeModules (consumed by private/)
├── home/              # home-manager modules — one .nix per tool
├── neovim/            # Full nvim config (see neovim/AGENTS.md)
├── desktop/
│   ├── configuration.nix  # Cross-platform system config; conditionally imports darwin.nix / linux.nix
│   ├── darwin.nix         # Darwin-only system options (Touch ID, startup chime, libiconv LIBRARY_PATH, xcbuild)
│   └── linux.nix          # NixOS-only system options (docker, tailscale)
├── terminal/          # ghostty, starship, kubie raw config files
├── tsnip/             # Deno-based TypeScript snippet definitions for tsnip.nvim
├── lazygit/           # lazygit config.yml (placed via home.file in git.nix)
├── ime/               # macSKK kana-rule.conf (placed via home.activation on Darwin; also reused as skkeleton's kana table on both OSes)
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
| Add a cross-platform system package | `desktop/configuration.nix` `environment.systemPackages` |
| Add a darwin-only system option | `desktop/darwin.nix` |
| Add a nixos-only system option | `desktop/linux.nix` |
| Add a home-manager module | `home/<tool>.nix` + add to `home/home.nix` `imports` |
| Add a user package | `home/home.nix` `home.packages` (wrap darwin-only ones in `lib.optionals pkgs.stdenv.isDarwin [...]`) |
| Place a config file | Relevant `home/*.nix` using `home.file."<path>".source` |
| Edit CI | `.github/workflows/format.yaml` |

## CONVENTIONS

- `flake.nix` exports two module functions: `desktopModules` and `homeModules` — both take `system` via `eachDefaultSystem`
- Overlays for neovim-nightly and lazygit are applied in `pkgs-module`, not `pkgs` (separate nixpkgs instance)
- `allowUnfree = true` only on `pkgs-module`
- System-level modules fan out via `imports = lib.optionals pkgs.stdenv.is<os> [ ./<os>.nix ]` — options that exist only on one OS go in `darwin.nix` or `linux.nix`, not guarded by `mkIf` in shared modules
- Formatter (`nix fmt`) runs both `nixfmt` and `stylua` in one script

## ANTI-PATTERNS

- Never add personal identity data here — that belongs in `private/`
- Never add raw config files without a corresponding `home.file` placement in a `.nix` module
- ime/kana-rule.conf uses `home.activation` (not `home.file`) on Darwin due to the macOS TCC sandbox — do not change to `home.file` on that path
- Never set an OS-specific option (e.g. `security.pam.services.sudo_local.touchIdAuth`, `virtualisation.docker.enable`) in a shared module even under `lib.mkIf` — the option path is evaluated independently of the value and will error as unknown. Put it in `darwin.nix` / `linux.nix`.
