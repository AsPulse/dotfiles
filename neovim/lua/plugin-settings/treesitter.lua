--- @type LazyPluginSpec[]
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
        opts = { },
      },
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
          'helm',
        },
        highlight = { enable = true },
        indent = { enable = false },
        yati = {
          enable = true,
          disable = { 'python' },

          default_lazy = true,

          default_fallback = 'auto'
        },
      }
      vim.filetype.add({
        extension = {
          gotmpl = 'gotmpl',
        },
        pattern = {
          [".*/templates/.*%.tpl"] = "helm",
          [".*/templates/.*%.ya?ml"] = "helm",
          ["helmfile.*%.ya?ml"] = "helm",
        },
      })
    end
  },
  {
    'norcalli/nvim-colorizer.lua',
    event = { 'BufAdd *.*', 'VeryLazy' },
    opts = { },
  },
}
