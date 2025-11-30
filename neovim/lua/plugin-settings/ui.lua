--- @type LazyPluginSpec[]
return {
  {
    'MunifTanjim/nui.nvim',
    lazy = true,
  },
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      presets = {
        bottom_search = true,
      },
      notify = { enabled = false },
    },
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    --- @type wk.Opts
    opts = {
      preset = 'helix',
    },
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufEnter *.*', 'VeryLazy' },
    opts = {
      signcolumn = false,
      numhl = true,
    },
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    enabled = false,
    event = { 'BufEnter *.*', 'VeryLazy' },
    dependencies = { 'marko-cerovac/material.nvim' },
    opts = {},
  },
  {
    'shellRaining/hlchunk.nvim',
    event = { 'BufEnter *.*', 'VeryLazy' },
    opts = {},
  },
  {
    'j-hui/fidget.nvim',
    event = { 'BufEnter *.*' },
    tag = 'legacy',
    opts = {
      text = {
        spinner = 'dots_pulse',
      },
    },
  },
}
