--- @type LazyPluginSpec[]
return {
  {
    'kevinhwang91/nvim-bqf',
    event = 'BufEnter *.*',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },
  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    cmd = 'Trouble',
    init = function()
      local options = { silent = true, noremap = true }
      vim.keymap.set('n', '<leader>dw', '<cmd>Trouble diagnostics<cr>', options)
    end,
    opts = {},
  },
}
