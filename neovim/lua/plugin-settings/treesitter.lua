--- @type LazyPluginSpec[]
return {
  {
    'nvim-treesitter/nvim-treesitter',
    event = { 'BufEnter *.*', 'VeryLazy' },
    build = ':TSUpdate',
    version = '*',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter-context',
        opts = {},
      }
    },
    config = function()
      require('nvim-treesitter.configs').setup({
        sync_install = false,
        auto_install = false,
        ignore_install = {},
        modules = {},
        ensure_installed = {
          'html',
          'css',
          'typescript',
          'tsx',
          'jsdoc',
          'dockerfile',
          'diff',
          'git_rebase',
          'gitattributes',
          'gitcommit',
          'gitignore',
          'rust',
          'c_sharp',
          'python',
          'gdscript',
          'godot_resource',
          'lua',
          'markdown',
          'markdown_inline',
          'json5',
          'yaml',
          'toml',
          'cpp',
          'helm',
          'latex',
          'nix',
          'csv',
          'sql',
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
      vim.filetype.add({
        extension = {
          gotmpl = 'gotmpl',
        },
        pattern = {
          ['.*/templates/.*%.tpl'] = 'helm',
          ['.*/templates/.*%.ya?ml'] = 'helm',
          ['helmfile.*%.ya?ml'] = 'helm',
        },
      })
    end,
  },
  {
    'norcalli/nvim-colorizer.lua',
    event = { 'BufAdd *.*', 'VeryLazy' },
    opts = {},
  },
}
