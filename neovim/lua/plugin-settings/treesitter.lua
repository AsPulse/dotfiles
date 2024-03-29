return {
  {
    'yioneko/nvim-yati',
    event = { 'BufEnter *.*', 'VeryLazy' },
    version = '*',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
      },
      {
        'nvim-treesitter/nvim-treesitter-context',
        config = function()
          require('treesitter-context').setup ({})
        end
      }
    },
    config = function()
      require('nvim-treesitter.configs').setup {
        sync_install = false,
        auto_install = false,
        ignore_install = {},
        modules = {},
        ensure_installed = {
          'typescript', 'tsx', 'jsdoc',
          'diff',
          'dockerfile',
          'git_rebase', 'gitattributes', 'gitcommit', 'gitignore',
          'rust', "c_sharp",
          'python',
          'gdscript', 'godot_resource',
          'html', 'json5', 'lua', 'markdown', 'markdown_inline', 'yaml', 'toml',
          'cpp',
        },
        highlight = { enable = true },
        indent = { enable = false },
        yati = {
          enable = true,
          disable = { 'python' },

          default_lazy = true,

          default_fallback = 'auto'
        }
      }
    end
  },
  {
    'norcalli/nvim-colorizer.lua',
    event = { 'BufAdd *.*', 'VeryLazy' },
    config = function()
      require('colorizer').setup()
    end
  }
}
