--- @type LazyPluginSpec[]
return {
  {
    'mrcjkb/rustaceanvim',
    version = '^4',
    lazy = true,
    ft = { 'rust' },
    dependencies = {
      'rust-lang/rust.vim',
      'neovim/nvim-lspconfig',
      'mfussenegger/nvim-dap',
    },
    init = function()
      -- Rust
      vim.g.rustaceanvim = {
        server = {
          on_attach = function(_, bufnr)
            vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
              buffer = bufnr,
              callback = function()
                if vim.fn.exists(':RustFmt') > 0 then
                  vim.cmd([[RustFmt]])
                else
                  print('rustfmt not found')
                end
              end
            })
          end,
          default_settings = {
            ["rust-analyzer"] = {
              check = {
                command = 'clippy'
              },
              lens = {
                enable = true
              },
              assist = {
                importGranularity = "module",
                importPrefix = "self",
              },
              cargo = {
                loadOutDirsFromCheck = true
              },
              procMacro = {
                enable = true
              },
              checkOnSave = true,
            }
          },
        }
      }
    end,
  },
  {
    'AsPulse/nvim-lspconfig',
    branch = 'feat(lsp)/smarter-typescript-project-detection',
    lazy = true,
    event = { 'BufEnter *.*', 'VeryLazy' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvimdev/lspsaga.nvim',
      'SmiteshP/nvim-navic',
      'simrat39/rust-tools.nvim',
      'b0o/schemastore.nvim',
    },
    config = function()
      -- texlab
      vim.lsp.config['texlab'] = {
        on_attach = function(_, bufnr)
          -- Add OpenSkim command to open PDF in Skim
          vim.api.nvim_buf_create_user_command(bufnr, 'OpenSkim', function()
            local tex_file = vim.fn.expand('%:p')
            local pdf_file = vim.fn.fnamemodify(tex_file, ':r') .. '.pdf'
            local cmd = string.format('open -a Skim.app "%s"', pdf_file)
            vim.fn.system(cmd)
          end, { desc = 'Open corresponding PDF file in Skim' })
        end,
        settings = {
          texlab = {
            build = {
              executable = 'lualatex',
              args = { '-synctex=1', '%f' },
              onSave = true,
              forwardSearchAfter = false,
            },
          }
        }
      }

      vim.lsp.enable('texlab')

      -- tsserver
      vim.lsp.config['ts_ls'] = {
        single_file_support = false,
      }

      vim.lsp.enable('ts_ls')

      vim.lsp.enable('eslint')
      vim.lsp.enable('biome')

      -- Denols
      vim.lsp.config['denols'] = {
        single_file_support = false,
        init_options = {
          lint = true,
          unstable = true
        }
      }

      vim.lsp.enable('denols')

      -- tailwindcss
      vim.lsp.enable('tailwindcss')

      -- Dockerls
      vim.lsp.enable('dockerls')

      -- Lua Language Server
      vim.lsp.config['lua_ls'] = {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
              pathStrict = true,
              path = { "?.lua", "?/init.lua" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("lua", true),
              checkThirdParty = "Disable",
            },
          },
        },
      }

      vim.lsp.enable('lua_ls')

      vim.api.nvim_create_autocmd('User', {
        pattern = 'LazyLoad',
        callback = function()
          vim.lsp.config['lua_ls'].settings.Lua.workspace.library = vim.api.nvim_get_runtime_file("lua", true)
        end
      })

      -- jsonls
      vim.lsp.config['jsonls'] = {
        filetypes = { "json", "jsonc", "jsonl", "json5" },
        settings = {
          json = {
          schemas = require('schemastore').json.schemas(),
            validate = { enable = true },
          }
        }
      }

      vim.lsp.enable('jsonls')

      -- yamlls
      vim.lsp.config['yamlls'] = {
        settings = {
          yaml = {
            schemaStore = {
              enable = false,
              url = "",
            },
            schemas = require('schemastore').yaml.schemas(),
          }
        }
      }

      vim.lsp.enable('yamlls')

      -- tombi
      vim.lsp.config['tombi'] = {
        filetypes = { 'toml' },
        settings = {
          toml = {
            schema = {
              enable = true,
              strict = true,
              catalog = {
                paths = {
                  "tombi://json.schemastore.org/api/json/catalog.json",
                  "https://json.schemastore.org/api/json/catalog.json",
                },
              },
            },
          },
        },
      }

      vim.lsp.enable('tombi')

      -- bash-language-server
      vim.lsp.config['bashls'] = {
        filetypes = { 'sh', 'zsh' }
      }

      vim.lsp.enable('bashls')

      -- nixd (Nix language server)
      vim.lsp.config['nixd'] = {}

      vim.lsp.enable('nixd')

      -- Pyright (Python language server)
      vim.lsp.config['pyright'] = {
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "workspace",
              useLibraryCodeForTypes = true,
              typeCheckingMode = "standard",
            },
          },
        },
      }

      vim.lsp.enable('pyright')

      -- LspAttach Setup
      local navic = require('nvim-navic')
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspConfig', {}),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client == nil then
            print('No client found on LspAttach. (lsp.lua)');
            return
          end
          if client.server_capabilities.documentSymbolProvider then
            navic.attach(client, event.buf)
          end
          local bufopts = { noremap = true, silent = true, buffer = event.buf }
          vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, bufopts)
          vim.keymap.set('n', '<leader>gr', vim.lsp.buf.references, bufopts)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end
      })

      local signs = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.HINT] = "",
        [vim.diagnostic.severity.INFO] = " ",
      };


      vim.diagnostic.config({
        virtual_lines = {
          format = function (diagnostic)
            return string.format(
              "%s %s (%s: %s)",
              signs[diagnostic.severity] or "●", diagnostic.message, diagnostic.source, diagnostic.code
            )
          end
        },
        signs = { text = signs },
      })

    end
  },
  {
    'nvimdev/lspsaga.nvim',
    event = { 'BufEnter *.*' },
    dependencies = {
      'williamboman/mason-lspconfig.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    config = function ()
      require('lspsaga').setup({
        ui = {
          border = 'rounded',
        }
      })
      vim.keymap.set('n', '<leader>rn', function() vim.api.nvim_command('Lspsaga rename') end, {})
      vim.keymap.set('n', '<leader>ac', function() vim.api.nvim_command('Lspsaga code_action') end, {})
      vim.keymap.set('n', 'K', function() vim.api.nvim_command('Lspsaga hover_doc') end, {})
    end
  },
  {
    'stevearc/dressing.nvim',
    event = 'BufEnter *.*',
    opts = { },
  },
  {
    'folke/lsp-colors.nvim',
    event = 'BufEnter *.*',
  },
  {
    'MysticalDevil/inlay-hints.nvim',
    event = 'LspAttach',
    config = function()
        require("inlay-hints").setup()
    end
  }
}
