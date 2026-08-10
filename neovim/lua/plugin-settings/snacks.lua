--- @type LazyPluginSpec
return {
  'folke/snacks.nvim',
  --- @type snacks.Config
  opts = {
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    lazygit = {
      configure = false,
    },
    indent = { enabled = true },
    explorer = {
      hidden = true,
      ignored = true,
    },
    picker = {
      enabled = true,
      sources = {
        explorer = {
          auto_close = true,
        },
      },
    },
  },
  keys = {
    --- Explorer
    { '<C-f>', function() Snacks.explorer.open() end, desc = 'Open Snack Explorer' },

    --- Buffers (前後移動は大西配列の物理位置に合わせて K / S)
    { 'K', function() vim.cmd.bp() end, desc = 'Go to Previous Buffer' },
    { 'S', function() vim.cmd.bn() end, desc = 'Go to Next Buffer' },
    { 'W', function() Snacks.bufdelete() end, desc = 'Close Buffer and Go to Next' },

    --- Tabs
    { '<M-k>', function() vim.cmd.tabprevious() end, desc = 'Go to Previous Tab', mode = { 'n', 't' } },
    { '<M-s>', function() vim.cmd.tabnext() end, desc = 'Go to Next Tab', mode = { 'n', 't' } },

    --- Lazygit
    { '<leader>git', function() Snacks.lazygit.open() end, desc = 'Open Lazygit' },

    --- Fizzy Finders
    { '<leader>ff', function() Snacks.picker.smart() end, desc = 'Open Snack Smart Picker' },
    { '<leader>fg', function() Snacks.picker.grep() end, desc = 'Open Snack Grep Picker' },
    { '<leader>fb', function() Snacks.picker.buffers() end, desc = 'Open Snack Buffers Picker' },

    { '<leader>pick', function() Snacks.picker.pickers() end, desc = 'List Snack Pickers' },
  },
}
