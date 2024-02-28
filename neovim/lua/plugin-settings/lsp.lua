return {
  {
    'neovim/nvim-lspconfig',
    lazy = true,
    dependencies = {
      'jose-elias-alvarez/null-ls.nvim',
      'nvim-lua/plenary.nvim',
      'nvimdev/lspsaga.nvim',
      'SmiteshP/nvim-navic',
    },
    config = function()
      local null_ls = require('null-ls')
      null_ls.setup({
        sources = {
          null_ls.builtins.diagnostics.editorconfig_checker
        }
      })

      local lspconfig = require('lspconfig')

      -- Lua Language Server
      lspconfig.lua_ls.setup({
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
              pathStrict = true,
              path = { "?.lua", "?/init.lua" },
            },
            workspace = {
              library = vim.list_extend(vim.api.nvim_get_runtime_file("lua", true), {
                "${3rd}/luv/library",
                "${3rd}/busted/library",
                "${3rd}/luassert/library",
              }),
              checkThirdParty = "Disable",
            },
          },
        },
      })


      -- LspAttach Setup
      local navic = require('nvim-navic')
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspConfig', {}),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.client_id)
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
    config = function ()
      require('dressing').setup()
    end
  },
  {
    'folke/lsp-colors.nvim',
    event = 'BufEnter *.*',
  },
}
