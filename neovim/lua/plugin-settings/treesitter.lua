--- @type LazyPluginSpec[]
return {
  {
    'nvim-treesitter/nvim-treesitter',
    -- master ブランチは 2025-05 にアーカイブされ、custom directive が
    -- Neovim 0.12 の query API と非互換になっている
    branch = 'main',
    -- main ブランチには highlight / indent モジュールが無く、
    -- parser と queries を rtp へ載せるのも起動時に済ませる必要がある
    lazy = false,
    build = ':TSUpdate',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter-context',
        opts = {},
      },
    },
    config = function()
      require('nvim-treesitter').install({
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
        'sql',
      })

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-enable', {}),
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(args.match)
          if not lang then return end

          local ok, added = pcall(vim.treesitter.language.add, lang)
          if not ok or not added then return end

          vim.treesitter.start(args.buf, lang)
          if vim.treesitter.query.get(lang, 'indents') then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
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
